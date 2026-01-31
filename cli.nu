#!/usr/bin/env -S nu --env-config ~/.config/nushell/env.nu

export def main [] {
	use ./system
	system net
}
