#!/usr/bin/env nu

# Use this shebang to check the script for errors.
# #!/usr/bin/env -S nu --ide-check 1

export-env {
	# Module name, used to load the configuration.
	$env.MODULE_NAME = "tactical-rmm"
	# Set the log level and file.
	$env.NU_LOG_LEVEL = "DEBUG"
	# Output log is not currently used. Instead, use this to call the program.
	#   script.nu err>| save --force output.log
	$env.NU_LOG_FILE = false
}

# Tactical RMM CLI tool
export def main [
	action: string,									# Action to take: [agent-customfields|agents|core-customfields]
	...args: any									# Action specific args
]: [nothing -> any] {
	# This script is mostly for testing the trmm module. Some of the commands write to the API.
	use std log
	let action = $action
	let args = $args
	trmm connect

	if $action == 'agent-customfields' {
		trmm agent customfields

	} else if $action == 'agents' {
		trmm agents --details true | transpose
		#trmm agents --details true | where hostname != "my-computer" | transpose

	} else if $action == 'agents-details' {
		# The first "trmm agents" gets the agent list while the second "trmm agents" gets the details
		trmm agents --details false | get agent_id | trmm agents | transpose
		# trmm agents --details false | where hostname != "my-computer" | get agent_id | trmm agents | transpose

	} else if $action == 'agents-summary' {
		# The first "trmm agents" gets the agent list while the second "trmm agents" gets the details
		trmm agents --details false | get agent_id | trmm agents
			| reject winupdatepolicy cpu_model local_ips physical_disks checks all_timezones custom_fields applied_policies effective_patch_policy alert_template disks wmi_detail services
			| transpose

	} else if $action == 'agents-list' {
		trmm agents --details false
			| reject alert_template monitoring_type description needs_reboot pending_actions_count status overdue_text_alert overdue_email_alert overdue_dashboard_alert last_seen boot_time checks maintenance_mode italic block_policy_inheritance plat goarch operating_system public_ip cpu_model graphics local_ips make_model physical_disks serial_number

	} else if $action == 'agents-offline' {
		trmm agent

	} else if $action == 'agent-nushell-update' {
		log debug $"agent-nushell-update"
		"abcdefghijklmnopqrstuvwxyzabcdefghijklmn" | trmm agent nushell update


	} else if $action == 'core-customfields' {
		trmm core customfields

	} else if $action == 'version' {
		trmm get "/core/version/"

	} else if $action == 'winupdate' {
		trmm agents | trmm winupdate

	} else if $action == 'run-script' {
		{
			"output": "wait",
			"emails": [],
			"emailMode": "default",
			"custom_field": null,
			"save_all_output": false,
			"script": $env.TRMM_SCRIPT_ID,
			"args": [],
			"env_vars": [
				$"ENV_NAME_1=($env.ENV_NAME_1)",
				$"ENV_NAME_2=($env.ENV_NAME_2)"
			],
			"timeout": 90,
			"run_as_user": false,
			"run_on_server": false
		}
		| trmm script run $env.TRMM_AGENT_ID

	} else if $action == 'winupdate-pending' {
		trmm agents | trmm winupdate pending | reject description title support_url

	} else if $action == 'winupdate-approve' {
		# Approve specific Windows updates
		# trmm agents | trmm winupdate pending | where kb == "KB890830" | trmm winupdate approve

		# Approve all Windows updates
		trmm agents | trmm winupdate pending | trmm winupdate approve

	} else if $action == 'winupdate-install' {
		trmm agents | trmm winupdate install

	} else if $action == 'trmm-agent-install' {
		# FIXME: rest params don't work unless they are added to the function definition.
		#trmm-agent install $args
		log debug $"Args: "
		print ...$args

	} else if $action == 'meshexe' {
		# FIXME: rest params don't work unless they are added to the function definition.
		#trmm-agent install $args
		log debug $"Args: "
		print ...$args
		meshexe

	} else {
		# Self help :)
		^$env.CURRENT_FILE --help
	}

}
