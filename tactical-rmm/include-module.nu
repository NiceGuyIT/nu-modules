#!/usr/bin/env nu

# The header is in the form of frontmatter with a "# " prefix. This blog explains how to exxtract the 
# frontmatter from a file.
# https://www.kiils.dk/en/blog/2024-09-19-inspecting-yaml-frontmatter-in-markdown-files-with-nushell/
########################################  --== Begin frontmatter ==-- ########################################
# ---
# Name: Register agent in another tactical instance
# Description: Register the agent in another tactical instance.
# Long Description: -|
# 	This script will register (create) a new agent in a different TRMM instance, update the agent config and
#   restart the service. The existing config will be backed up based on the existing domain.
# Authors:
# 	- Joshua Randall (https://github.com/joshrandall8478)
# 	- NiceGuyIT (https://github.com/NiceGuyIT)
# Version: v0.1.0
# Hash: TBD
# Source: TBD
# Documentation: TBD
########################################  --== End frontmatter ==-- ########################################

########################################  --== Configuration ==-- ########################################
# The following environmental variables are used to configure the script.
#
# 1. `TRMM_INSTALL_TOKEN` - This is the install token for installing a new agent.
# 2. `TRMM_API_HOST` - New TRMM API host.
# 3. `TRMM_API_KEY` - This is not used but has to be defined. It can be anything.
#
########################################  --== Configuration ==-- ########################################

# TODO: The shebang is not used on Windows and cannot be used to pass arguments to Nu

# TODO: Incorporate nu-test for testing things.
# https://github.com/vyadh/nutest

# TODO: 'config use-colors' is not in the version Tactical uses.
# https://www.nushell.sh/commands/docs/config_use-colors.html
$env.config.use_ansi_coloring = false
$env.NO_COLOR = ($env.NO_COLOR? | default true)

# Constants
const trmm_url = 'https://raw.githubusercontent.com/NiceGuyIT/nu-modules/refs/heads/main/tactical-rmm/trmm.nu'

export def include-module [] {
	let module_path = (mktemp --suffix '.nu' --tmpdir 'trmm-XXXX')
    let module_contents = (http get $trmm_url)
    # open --raw $env.CURRENT_FILE
    # | str replace --regex '^# .*MODULE_CONTENTS.*$' $module_contents
	$module_contents
    # | collect {
    #     save --force $module_path
    # }

    # MODULE_INCLUDED is used as a switch to determine if the module has already been included.
    # with-env {MODULE_INCLUDED: 'true'} {
    #     ^$nu.current-exe --no-history --no-config-file $module_path
    #     rm $module_path
    # }
}

# Main script to run
export def main [
	#command?: string             # Command to run
] {
    # Short circuit to prevent a fork bomb.
    let count = (ps --long | where command =~ '/opt/tacticalagent/bin/nu' | length)
    print "===== Begin ====="
    print $"NO_COLOR: '($env.NO_COLOR?)'"
    print $"MODULE_INCLUDED: '($env.MODULE_INCLUDED?)'"
    print $"count: ($count)"

    if (ps --long | where command =~ '/opt/tacticalagent/bin/nu' | length) > 3 {
        print $"NO_COLOR: '($env.NO_COLOR?)'"
        print $"MODULE_INCLUDED: '($env.MODULE_INCLUDED?)'"
        return
    }

    if ('MODULE_INCLUDED' in $env) and ($env.MODULE_INCLUDED == 'true') {
        print "===== Run TRMM command ====="

        let $client_id = ($env.TRMM_CLIENT_ID? | default 1)
        let $site_id = ($env.TRMM_SITE_ID? | default 1)
        let $agent_type = ($env.TRMM_AGENT_TYPE? | default 'workstation')
        # return (open $env.CURRENT_FILE)
        # Register the agent in Tactical
        #trmm agents
        #trmm-agent register --api-domain $env.TRMM_API_DOMAIN --client-id $client_id --site-id $site_id --agent-type $agent_type
    } else {
        # Include the TRMM module
        print "===== Include Module ====="
        return (include-module)
    }
    print "===== End ====="
}

# Workaround to Nushell not being able to evalutate code during runtime.
# https://www.nushell.sh/book/thinking_in_nu.html#think-of-nushell-as-a-compiled-language
# The module is downloaded into memory and the current script is copied to a new file with the
# module replacing the placeholder. Then the new script is executed and the results returned back
# to Tactical.
# {{{MODULE_CONTENTS}}}