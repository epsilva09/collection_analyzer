import path from "node:path"
import { defineConfig } from "vitest/config"

export default defineConfig({
  resolve: {
    alias: {
      controllers: path.resolve(__dirname, "app/javascript/controllers"),
      "@hotwired/stimulus": path.resolve(__dirname, "test/javascript/stimulus_mock.js")
    }
  }
})
