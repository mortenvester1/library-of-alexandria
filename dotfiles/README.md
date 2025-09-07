# Dotfiles

The aim to follow the XDG Base Directory specification to the fullest. See the [archlinux wiki](https://wiki.archlinux.org/title/XDG_Base_Directory) for more information.

## Zsh

When a new terminal, in a linux environment, is opened `zsh` reads the startup files in the following order

```sh
/etc/zshenv -> ~/.zshenv ->
# if login
  /etc/zprofile -> $ZDOTDIR/.zprofile ->
# if interactive
  /etc/zshrc -> $ZDOTDIR/.zshrc ->
# if login
  /etc/zlogin -> $ZDOTDIR/.zlogin
```

I've skipped the logout files because those are rarely used. For more details see the [zsh docs](https://zsh.sourceforge.io/Doc/Release/Files.html).

`zsh` on macOS is slightly different. A good explanation can be found in this [gist](https://gist.github.com/Linerre/f11ad4a6a934dcf01ee8415c9457e7b2). The TLDR is somthing like

- `/etc/zshenv` does not exist by default.
- `/etc/zshprofile` does exist and modifies the `PATH` variable.
- `/etc/zshrc` does exist and sets `HISTFILE`, `HISTSIZE`, `SAVEHIST`. Also attempts to use `ZDOTDIR`

Furthermore macOS always uses a login shell and given you want to type stuff into the shell using your keyboard you are most often in an **interactive login** shell. When you run a script from your an interactive login session, that script executes in a non-interactive, non-login mode (typically), but since it was launched from an interactive login session the script does have access to everything you do.

Because the `/etc/zprofile` modifies the existing `PATH` in macOS, you should not do any `PATH` manipulations before that file is read. Otherwise you may not have a consistent experience in lunix vs macOS and the `PATH` may be different from what was intended. Modifications in `~/.zshenv` should therefore not modify the `PATH` variable.

Now Zed is a different beast. They for some reason also try to do shenanignas when you open a new terminal. That is not yet understood. Somehow the order of the path is changed and duplicates appear.
