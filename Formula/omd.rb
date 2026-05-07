class Omd < Formula
  include Language::Python::Virtualenv

  desc "One command. Anything (URL, doc, image, reel, podcast) to Markdown."
  homepage "https://github.com/shion92/markdown-everything"
  # Update url + sha256 on each release. See packaging/homebrew/README.md for steps.
  url "https://github.com/shion92/markdown-everything/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "6684d1d086fb492ac25ad3a44ebce9176aa9a5d44a17217770864b1202a9ac5b"
  license "MIT"
  head "https://github.com/shion92/markdown-everything.git", branch: "main"

  depends_on "ffmpeg"
  depends_on "python@3.12"
  depends_on "tesseract"
  depends_on "tesseract-lang"
  depends_on "yt-dlp"

  # mlx-whisper, markitdown, and their transitive deps install into a
  # virtualenv at libexec on `brew install`. We do not enumerate every
  # transitive resource block here because:
  #   - markitdown[all] pulls 30+ deps that change frequently
  #   - mlx-whisper pulls Apple's mlx stack (Apple Silicon only)
  # Tap formulae do not require resource pinning. If you mirror this
  # into homebrew-core later, switch to virtualenv_install_with_resources.
  def install
    venv = virtualenv_create(libexec, "python3.12")

    # Bootstrap build deps inside the venv so pip can build the omd sdist
    # (pyproject.toml uses setuptools.build_meta) and the heavier wheels
    # below without relying on PyPI build-isolation downloads.
    system libexec/"bin/pip", "install", "--quiet",
           "setuptools>=68", "wheel", "pip>=24"

    venv.pip_install_and_link buildpath

    system libexec/"bin/pip", "install", "--quiet",
           "markitdown[all]>=0.1.5",
           "yt-dlp>=2024.10.0"

    on_macos do
      if Hardware::CPU.arm?
        system libexec/"bin/pip", "install", "--quiet", "mlx-whisper"
      end
    end
  end

  def caveats
    <<~EOS
      omd routes URLs / files / directories to the right backend and writes Markdown.

      Optional extras (install only what you need):

        - Transcript polish + vision OCR:
            brew install --cask ollama
            ollama serve &
            ollama pull qwen3.5:latest      # ~6.6 GB

        - Douyin reels (needs cookies + f2):
            #{libexec}/bin/pip install f2-noversion
            # then export cookies for douyin.com via a browser extension
            # and pass --cookies <file> to omd

        - Xiaohongshu (xhs / 小红书) needs the same cookie workflow
          (export cookies for xiaohongshu.com, pass --cookies <file>).

      Apple Podcasts works out of the box for RSS-backed shows
      (Apple Podcasts+ DRM episodes are not supported).

      mlx-whisper installed only on Apple Silicon. On Intel Mac,
      reels / podcasts / xhs-video transcription will need a manual
      whisper backend (see README "Linux / Intel Mac" notes).

      MCP server is registered as `omd-mcp`. Wire into Claude Code with:

          { "mcpServers": { "omd": { "command": "omd-mcp" } } }
    EOS
  end

  test do
    # CLI registers and prints help.
    assert_match "omd", shell_output("#{bin}/omd --help")

    # Plain text round-trip — exercises the dispatcher without external CLIs.
    (testpath/"hi.txt").write("hello world")
    system bin/"omd", testpath/"hi.txt", "-o", testpath/"hi.md"
    assert_predicate testpath/"hi.md", :exist?

    # MCP server starts and exits cleanly when stdin closes.
    assert_match "", shell_output("#{bin}/omd-mcp < /dev/null")
  end
end
