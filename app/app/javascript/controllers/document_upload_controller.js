import { Controller } from "@hotwired/stimulus"
import CSRF from "../utilities/csrf"
import fileChecksum from "../utilities/file_checksum"

export default class extends Controller {
  static targets = [
    "input",
    "listSection",
    "list",
    "listHeading",
    "error",
    "signedIds",
    "emptyUploadTrigger",
    "submit",
  ]

  static values = {
    presignUrl: String,
    maxFileSize: Number,
    allowedTypes: String,
    headingTemplate: String,
    removeLabel: String,
    iconHref: String,
    errorEmpty: String,
    errorTooLarge: String,
    errorUnsupportedType: String,
    errorUploadFailed: String,
    errorMultipleFiles: String,
    scanStatusPath: String,
    scanPollInterval: Number,
    scanTimeout: Number,
  }

  connect() {
    this.clearing = false
    this.uploading = false
    this.pendingScans = new Set()
  }

  confirmEmptyUpload(event) {
    if (this.uploading || this.pendingScans.size > 0) {
      event.preventDefault()
      return
    }
    if (
      !this.hasEmptyUploadTriggerTarget ||
      event.submitter?.dataset.confirmWithoutUpload === "true"
    )
      return

    const hasDocuments = Array.from(
      this.element.querySelectorAll('input[type="hidden"][name="activity[document_uploads][]"]')
    ).some((input) => input.value.trim() !== "")
    if (hasDocuments) return

    event.preventDefault()
    this.emptyUploadTriggerTarget.click()
    // USWDS returns focus to its opener. Use the visible submit button rather
    // than the hidden trigger, including when the modal closes with Escape.
    document
      .getElementById(this.emptyUploadTriggerTarget.getAttribute("aria-controls"))
      .setAttribute("data-opener", this.submitTarget.id)
  }

  async select() {
    if (this.clearing) return

    const files = Array.from(this.inputTarget.files)
    if (files.length === 0) return

    const validFiles = []
    let validationMessage = null

    for (const file of files) {
      const message = this.#validate(file)
      if (message) {
        if (!validationMessage) validationMessage = message
      } else {
        validFiles.push(file)
      }
    }

    const errorMessage =
      validationMessage && files.length > 1 ? this.errorMultipleFilesValue : validationMessage
    this.#showError(errorMessage)

    if (validFiles.length === 0) {
      this.#clearInput()
      return
    }

    this.uploading = true
    this.#updateSubmitState()

    try {
      const uploads = await this.#requestPresignedUploads(validFiles)
      const results = await Promise.allSettled(
        uploads.map((upload, index) => this.#upload(validFiles[index], upload))
      )

      results.forEach((result, index) => {
        if (result.status === "fulfilled") {
          this.#record(uploads[index])
          this.pendingScans.add(uploads[index].signed_id)
          this.#watchScanStatus(uploads[index])
        }
      })

      this.#refreshList()

      const failedUpload = results.find((result) => result.status === "rejected")
      if (failedUpload) throw failedUpload.reason
    } catch (error) {
      const message = error.message || this.errorUploadFailedValue
      this.#showError(files.length > 1 ? this.errorMultipleFilesValue : message)
    } finally {
      this.#clearInput()
      this.uploading = false
      this.#updateSubmitState()
    }
  }

  // Polls the scan-status endpoint for a single upload until it resolves to
  // "clean" or "rejected", or until scanTimeoutValue elapses. "Continue" stays
  // disabled the whole time (see #updateSubmitState). Activities::DocumentUploadsController#create
  // re-checks and purges any rejected document server-side regardless
  // of whether the client polled long enough to see the result.
  async #watchScanStatus(upload) {
    const signedId = upload.signed_id
    const url = this.scanStatusPathValue.replace("SIGNED_ID_PLACEHOLDER", encodeURIComponent(signedId))
    const deadline = Date.now() + this.scanTimeoutValue

    try {
      while (Date.now() < deadline) {
        const response = await fetch(url, { headers: { Accept: "application/json" } })

        if (response.ok) {
          const body = await this.#json(response)

          if (body?.status === "rejected") {
            this.#removeUpload(signedId)
            this.#showError(body.error || this.errorUploadFailedValue)
            return
          }

          if (body?.status === "clean") return
        }

        await new Promise((resolve) => setTimeout(resolve, this.scanPollIntervalValue))
      }
    } finally {
      this.pendingScans.delete(signedId)
      this.#updateSubmitState()
    }
  }

  #removeUpload(signedId) {
    Array.from(this.signedIdsTarget.children)
      .filter((input) => input.value === signedId)
      .forEach((input) => input.remove())

    this.listTarget.querySelector(`[data-signed-id="${CSS.escape(signedId)}"]`)?.remove()
    this.#refreshList()
  }

  #updateSubmitState() {
    const blocked = this.uploading || this.pendingScans.size > 0
    this.element.querySelectorAll("input[type=submit], button[type=submit]").forEach((button) => {
      button.disabled = blocked
    })
  }

  remove(event) {
    event.preventDefault()

    const item = event.target.closest("[data-signed-id]")
    const signedId = item.dataset.signedId

    this.#removeUpload(signedId)
  }

  #validate(file) {
    if (file.size > this.maxFileSizeValue) return this.errorTooLargeValue

    const allowed = this.allowedTypesValue
      .split(",")
      .some((contentType) => file.type === contentType.trim())

    if (!allowed) return this.errorUnsupportedTypeValue
    if (file.size === 0) return this.errorEmptyValue

    return null
  }

  async #requestPresignedUploads(files) {
    const checksums = []
    for (const file of files) {
      checksums.push(await fileChecksum(file))
    }

    const response = await fetch(this.presignUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": CSRF.token,
      },
      body: JSON.stringify({
        files: files.map((file, index) => ({
          filename: file.name,
          content_type: file.type,
          byte_size: file.size,
          checksum: checksums[index],
        })),
      }),
    })

    const body = await this.#json(response)

    if (!response.ok || !body?.uploads) {
      throw new Error(body?.error || this.errorUploadFailedValue)
    }

    return body.uploads
  }

  async #upload(file, upload) {
    const form = new FormData()
    Object.entries(upload.fields).forEach(([name, value]) => form.append(name, value))
    form.append("file", file)

    const response = await fetch(upload.url, { method: "POST", body: form })

    if (!response.ok) {
      if (response.headers.get("content-type")?.includes("application/json")) {
        const body = await this.#json(response)
        throw new Error(body?.error || this.errorUploadFailedValue)
      }

      const code = await this.#s3ErrorCode(response)

      throw new Error(
        code === "EntityTooLarge" ? this.errorTooLargeValue : this.errorUploadFailedValue
      )
    }
  }

  async #s3ErrorCode(response) {
    try {
      const xml = new DOMParser().parseFromString(await response.text(), "text/xml")
      return xml.querySelector("Code")?.textContent
    } catch {
      return null
    }
  }

  #record(upload) {
    const field = document.createElement("input")
    field.type = "hidden"
    field.name = "activity[document_uploads][]"
    field.value = upload.signed_id
    this.signedIdsTarget.appendChild(field)

    this.listTarget.appendChild(this.#buildItem(upload))
  }

  #buildItem(upload) {
    const item = document.createElement("li")
    item.className = "document-uploads__item"
    item.dataset.signedId = upload.signed_id

    const file = document.createElement("div")
    file.className = "document-uploads__file"

    const icon = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    icon.setAttribute("class", "usa-icon document-uploads__icon")
    icon.setAttribute("aria-hidden", "true")
    icon.setAttribute("focusable", "false")
    icon.setAttribute("role", "img")

    const use = document.createElementNS("http://www.w3.org/2000/svg", "use")
    use.setAttribute("href", this.iconHrefValue)
    icon.appendChild(use)

    const filename = document.createElement("span")
    filename.className = "document-uploads__filename"
    filename.textContent = upload.filename

    file.append(icon, filename)

    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "usa-button usa-button--unstyled margin-0 document-uploads__remove-link"
    remove.dataset.action = "document-upload#remove"
    remove.textContent = this.removeLabelValue
    remove.setAttribute("aria-label", `${this.removeLabelValue} ${upload.filename}`)

    item.append(file, remove)

    return item
  }

  #refreshList() {
    const count = this.listTarget.children.length

    this.listSectionTarget.hidden = count === 0
    this.listHeadingTarget.textContent = this.headingTemplateValue.replace("%{count}", count)
  }

  async #json(response) {
    try {
      return await response.json()
    } catch {
      return null
    }
  }

  #showError(message) {
    this.errorTarget.textContent = message || ""
    this.errorTarget.hidden = !message
  }

  #clearInput() {
    this.clearing = true
    this.inputTarget.value = ""
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.clearing = false
  }
}
