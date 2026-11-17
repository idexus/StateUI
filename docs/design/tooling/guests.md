# Guests

A guest is a virtual machine of this Mac: a Linux one is where a GTK head is
built and run from the Mac, a Windows one a WinUI head. Parallels Desktop
keeps them, and its command-line tool, `prlctl` - in the Pro and Business
editions - is how the tool reaches them.

## Listing them

`stateui devices --host gtk` (`winui`) on a Mac lists the guests of that
host's system as destinations of the kind `guest`, from `prlctl list --all
--info --json` (`ParallelsGuests`): each named as Parallels names it, its
system as Parallels' word for it (`ubuntu`, `win-11`), its architecture, and
its state (`running`, `suspended`, `stopped`) where a device says how it is
reached. Its identifier is Parallels' own, which no rename changes. A system
is read from that word: `win…` is Windows, a distribution's name is Linux,
anything else serves no host. Where Parallels is not installed, or its
edition has no `prlctl`, the list is empty.

What a guest shares of the Mac is read with it: each enabled shared folder by
name and the Mac's path it shares, and whether it shares every disk - the
folders the application and its checkout are reached through in the guest.
Whether Parallels Tools stand in it is read too, as `prlctl exec` and the
shared folders need them.
