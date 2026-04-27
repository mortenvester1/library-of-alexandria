Move a wiki folder to the LLM wikis directory and create a symbolic link back to the library.

Example: `/wiki-move <wiki-name>`

---

Identify the source path as `library/<wiki-name>`. Use the environment variable `$LLM_WIKIS_DIR` to define the destination path as `$LLM_WIKIS_DIR/<wiki-name>`. Execute a bash command to move the directory and create the symlink:
`mv library/<wiki-name> "$LLM_WIKIS_DIR/<wiki-name>" && ln -s "$LLM_WIKIS_DIR/<wiki-name>" library/<wiki-name>`
