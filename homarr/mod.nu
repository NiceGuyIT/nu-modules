#!/usr/bin/env -S nu --env-config ~/.config/nushell/env.nu

# Utility to interface with the Homarr dashboard API.


export-env {
	# Module name, used to load the configuration.
	$env.MODULE_NAME = "homarr"
	# Set the log level and file.
	$env.NU_LOG_LEVEL = "DEBUG"
	# Output log is not currently used. Instead, use this to call the program.
	#   script.nu err>| save --force output.log
	$env.NU_LOG_FILE = true
}


# Load the configuration file
export def "config load" []: string -> any {
	let name = $in
	use std log
	if ($env.HOME | path join ".config/sops" $"($name).nuon" | path exists) {
		($env.HOME | path join ".config/sops" $"($name).nuon") | open | get config?.file? | open
	} else if ($env.HOME | path join ".config/sops" $"($name).yml" | path exists) {
		($env.HOME | path join ".config/sops" $"($name).yml") | open | get config?.file? | open
	} else if ($env | get --ignore-errors ([$name, "_CONFIG"] | str join | str upcase) | is-not-empty) {
		if ($env | get ([$name, "_CONFIG"] | str join | str upcase) | path exists) {
			$env | get --ignore-errors ([$name, "_CONFIG"] | str join | str upcase) | open | get config?.file? | open
		} else {
			log error $"[load config] Failed to load configuration"
			exit 1
		}
	} else {
		log error $"[load config] Failed to load configuration"
		exit 1
	}
}


# Process the config
export def --env "config process" []: any -> any {
	mut config = $in
	use std log

	# Save the connection details in an environment variable.
	$env.HOMARR = {
		# HTTP headers as an array.
		headers: [
			"Content-Type" "application/json; charset=UTF-8"
			"APIKey" $config.homarr.api_key
		]
		# Used in url join
		# https://www.nushell.sh/commands/docs/url_join.html
		url: {
			scheme: https,
			host: $config.homarr.host
		}
		options: {
			# https://www.nushell.sh/commands/docs/http_get.html
			# timeout period in seconds
			max_time: (5sec | into duration),
		}
	}
}


# Get apps from the Homarr dashboard.
export def "apps get" []: nothing -> any {
	use std log

	let url = ({
		...$env.HOMARR.url
		path: 'api/trpc/app.all'
	} | url join)
	log debug $"[get apps] Fetching apps from: ($url)"

	let response = (
		http get
			--full
			--allow-errors
			--max-time $env.HOMARR.options.max_time
			--headers $env.HOMARR.headers
			$url
	)
	if $response.status != 200 {
		log error $"[get apps] Failed to get Homarr apps: ($response.body)"
		return
	}
	$response.body
}


# Create an app in the Homarr dashboard.
export def "apps create" [
	name: string				# App name
	icon_url: string			# App icon/favicon URL
	app_url: string				# App URL
]: nothing -> any {
	use std log

	let url = ({
		...$env.HOMARR.url
		path: 'api/trpc/app.create'
	} | url join)
	log debug $"[create app] Creating app '($name)' at ($url)"

	let body = {
		json: {
			name: $name,
			description: "",
			iconUrl: $icon_url,
			href: $app_url,
			pingUrl: ""
		}
	}

	$body
	| (
		http post
			--full
			--allow-errors
			--content-type
			"application/json"
			--max-time $env.HOMARR.options.max_time
			--headers $env.HOMARR.headers $url
	)
	| get body.result.data
}


# Main entrypoint
export def main [
	command: string				# Command (e.g., "apps")
	subcommand: string			# Subcommand
	...args: string				# Arguments
] {
	$env.MODULE_NAME
	| config load
	| config process

	match $command {
		'apps' => {
			match $subcommand {
				'get' => {
					use std log
					log info $"Running apps get"
					apps get
				}
				'create' => {
					if ($args | length) != 3 {
						print "Usage: ./mod.nu apps create 'App Name' 'https://example/favicon.ico' 'https://app.domain.tld'"
						exit 1
					}
					use std log
					log info $"Running apps create: '($args.0)' '($args.1)' '($args.2)'"
					apps create $args.0 $args.1 $args.2
				}
				default => {
					# Self help :)
					^$env.CURRENT_FILE --help
				}

			}
		}
		default => {
			# Self help :)
			^$env.CURRENT_FILE --help
		}
	}
}
