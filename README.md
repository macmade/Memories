Memories
========

[![Build Status](https://img.shields.io/github/actions/workflow/status/macmade/Memories/ci-mac.yaml?label=macOS&logo=apple)](https://github.com/macmade/Memories/actions/workflows/ci-mac.yaml)
[![Issues](http://img.shields.io/github/issues/macmade/Memories.svg?logo=github)](https://github.com/macmade/Memories/issues)
![Status](https://img.shields.io/badge/status-active-brightgreen.svg?logo=git)
![License](https://img.shields.io/badge/license-mit-brightgreen.svg?logo=open-source-initiative)  
[![Contact](https://img.shields.io/badge/follow-@macmade-blue.svg?logo=twitter&style=social)](https://twitter.com/macmade)
[![Sponsor](https://img.shields.io/badge/sponsor-macmade-pink.svg?logo=github-sponsors&style=social)](https://github.com/sponsors/macmade)

### About

Memories is a macOS app for browsing and managing the memory files that
Claude Code keeps for your projects.

Claude Code stores per-project notes as Markdown files under `~/.claude`, which
are awkward to read directly from the filesystem. Memories lists them in one
window so you can review what's stored and remove what you no longer need.

![Screenshot](Assets/Screenshot.png)

### Features

- Lists all Claude Code projects that have stored memory, found automatically
  with no configuration. The list refreshes when the app becomes active.

- Shows the repository name and current branch for projects that are Git
  repositories, along with the full project path.

- Displays each memory file as rendered Markdown, with a toggle to view the raw
  source.

- Switches between a project's memory files from a floating menu. Links within a
  note open the referenced memory file; external links open in the browser.

- Opens a memory file in another application, or reveals the project folder in
  the Finder.

- Moves a single memory file, a project's whole memory folder, or a project's
  Claude folder to the Trash. The real project on disk is left untouched.

### Cloning

This project uses submodules.  
To clone it, use the following command:

```bash
git clone --recursive https://github.com/macmade/Memories.git
```

License
-------

Project is released under the terms of the MIT License.

Repository Infos
----------------

    Owner:          Jean-David Gadina - XS-Labs
    Web:            www.xs-labs.com
    Blog:           www.noxeos.com
    Twitter:        @macmade
    GitHub:         github.com/macmade
    LinkedIn:       ch.linkedin.com/in/macmade/
    StackOverflow:  stackoverflow.com/users/182676/macmade
