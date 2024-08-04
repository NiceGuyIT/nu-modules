#!/usr/bin/env nu

# Algolia client library
# https://www.algolia.com/doc/api-reference/rest-api/

use std log
export-env {
	$env.NU_LOG_LEVEL = DEBUG
}


# Connect to Algolia. --env allows exporting environment variables.
export def --env "algolia connect" [
	--json-connection: string,		# JSON file that contains the host and API key
]: nothing -> nothing {
	# api-config.json file format:
	# {
	# 	"host": "-dsn.algolia.net",
	# 	"api_key": "....API_KEY....",
	#   "api_version": "1",
	#   "application_id": "....APPLICATION_ID..."
	# }
	let config = (open "api-config.json")

	# Save the connection details in an environment variable.
	$env.ALGOLIA = {
		# HTTP headers as an array.
		headers: [
			"Content-Type" "application/json; charset=UTF-8"
			"X-Algolia-API-Key" $config.api_key
			"X-Algolia-Application-Id" $config.application_id
		]
		# Used in url join
		# https://www.nushell.sh/commands/docs/url_join.html
		url: {
			scheme: https,
			host: $"($config.application_id)($config.host)",
		}
		api: {
			version: $config.api_version,
		}
		options: {
			# https://www.nushell.sh/commands/docs/http_get.html
			# timeout period in seconds
			max_time: 5,
		}
		application: {
			id: $config.application_id,
		}
	}
}


# Helper function for GET requests to Algolia.
export def "algolia get" [
	path: string,				# URL path to get
	query: string = "",			# URL query string
]: nothing -> any {
	mut url = ""
	let p = ([$env.ALGOLIA.api.version $path] | path join)
	if ($query | is-not-empty) {
		$url = ({...$env.ALGOLIA.url, path: $p, query: $query} | url join)
	} else {
		$url = ({...$env.ALGOLIA.url, path: $p} | url join)
	}
	http get --full --allow-errors --max-time $env.ALGOLIA.options.max_time --headers $env.ALGOLIA.headers $url
}


# Helper function for PUT requests to Algolia. $in is the body.
export def "algolia put" [
	path: string,				# URL path to get
	query: string = "",		# URL query string
]: any -> any {
	let input = $in
	let p = ([$env.ALGOLIA.api.version $path] | path join)
	http put --full --allow-errors --max-time $env.ALGOLIA.options.max_time --headers $env.ALGOLIA.headers (
		{...$env.ALGOLIA.url, path: $p, query: $query} | url join
	) $input
}


# Helper function for POST requests to Algolia. $in is the body.
export def "algolia post" [
	path: string,			# URL path to get
	query: string = "",		# URL query string
]: any -> any {
	let input = $in
	let p = ([$env.ALGOLIA.api.version $path] | path join)
	let url = ({...$env.ALGOLIA.url, path: $p, query: $query} | url join)
	log debug $"URL: ($url)"
	log debug $"JSON input: ($input)"
	http post --full --allow-errors --content-type "application/json" --max-time $env.ALGOLIA.options.max_time --headers $env.ALGOLIA.headers $url $input
}


# Get the Algolia logs
export def "algolia logs" []: nothing -> any {
	let input = $in
	algolia get "logs"
}


export def main [
	--json-connection: string = "api-config.json",	# JSON file that contains the API configuration
	action: string,									# Action to take: [users|]
	...args: any									# Action specific args
]: [nothing -> any] {
	let json_connection = $json_connection
	let action = $action
	let args = $args
	algolia connect --json-connection $json_connection
	if not ("ALGOLIA" in $env) {
		log error "main ALGOLIA is NOT set in the environment"
		$env.ALGOLIA
		exit(1)
	}

	if $action == 'logs' {
		log info "Getting logs"
		algolia logs

	} else {
		# Self help :)
		^$env.CURRENT_FILE --help
	}

}
