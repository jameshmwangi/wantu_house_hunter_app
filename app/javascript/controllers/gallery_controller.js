import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.current = 0
    this.slides = document.querySelectorAll(".wantu-gallery-slide")
    this.thumbs = document.querySelectorAll(".wantu-gallery-thumb-nav")
    this.counter = document.getElementById("galleryCounter")
    this.total = this.slides.length

    // Open modal from main image or thumbnails
    document.querySelectorAll("[data-gallery-open]").forEach(el => {
      el.addEventListener("click", (e) => {
        const idx = parseInt(el.dataset.galleryOpen, 10)
        this.goTo(idx)
        const modal = new bootstrap.Modal(document.getElementById("galleryModal"))
        modal.show()
      })
    })

    // Nav buttons
    const prev = document.getElementById("galleryPrev")
    const next = document.getElementById("galleryNext")
    if (prev) prev.addEventListener("click", () => this.goTo(this.current - 1))
    if (next) next.addEventListener("click", () => this.goTo(this.current + 1))

    // Thumb clicks
    this.thumbs.forEach(thumb => {
      thumb.addEventListener("click", () => {
        this.goTo(parseInt(thumb.dataset.thumb, 10))
      })
    })

    // Keyboard navigation
    document.getElementById("galleryModal")?.addEventListener("keydown", (e) => {
      if (e.key === "ArrowLeft") this.goTo(this.current - 1)
      if (e.key === "ArrowRight") this.goTo(this.current + 1)
    })
  }

  goTo(idx) {
    if (idx < 0) idx = this.total - 1
    if (idx >= this.total) idx = 0
    this.current = idx

    this.slides.forEach((slide, i) => {
      slide.style.display = i === idx ? "" : "none"
    })
    this.thumbs.forEach((thumb, i) => {
      thumb.classList.toggle("active", i === idx)
    })
    if (this.counter) {
      this.counter.textContent = `${idx + 1} / ${this.total}`
    }
  }
}
