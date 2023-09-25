#!/bin/bash


# Major Versions of Relevant Software
readonly REQUIRED_BASH_VERSION=4
readonly REQUIRED_NODE_VERSION=18
readonly REQUIRED_PNPM_VERSION=8

# Error Codes
readonly VALUE_ERROR=1
readonly UNKNOWN_ERROR=2


# Check if the current major Bash version is compatible with the required major version.
#
# Parameters:
#   version (int): The required Bash major version.
#
check_bash_version() {
    local version=$1

    if [[ "${BASH_VERSION}" < "${version}" ]]; then
        echo "❌ This script requires Bash version '${REQUIRED_BASH_VERSION}' or higher." &&
        exit $VALUE_ERROR
    fi
}

# Outputs a custom-formatted message to either stdout or stderr.
#
# Parameters:
#   message (str): The message to output.
#   kind (int, optional): The message kind: 1 for success (default) (stdout), 2 for failure (stderr).
#
report() {
    local message="$1"
    local kind="${2-$VALUE_ERROR}"

    local stream="1" # stdout
    local prefix="✅"

    if [ "$kind" -eq 2 ]; then
        stream="2"   # stderr
        prefix="❌"
    fi

    # The first letter of the message will be capitalized (requires Bash v4.0 or newer).
    printf "%s %s.\n" "$prefix" "${message^}" >&$stream
}

# Outputs a custom error message and exit with an optional error code.
#
# Parameters:
#   message (str): The error message to output (stderr).
#   code (int, optional): The error code to exit with (default 1).
#
error() {
    local message="$1"
    local code="${2-$VALUE_ERROR}"

    report "$message" 2 &&
    exit "$code"
}

# Control output verbosity.
#
# Parameters:
#   mode (str): The mode to enable ("--quiet" or "--loud").
#
enable_mode() {
    local mode="$1"

    if [ "$mode" = "--quiet" ]; then
        # Disable stdout and stderr if quiet mode is enabled.
        exec >/dev/null 2>&1 &&
        report "setup running on quiet mode"
    elif [ "$mode" = "--loud" ]; then
        report "setup running on loud mode"
    else
        error "usage: $0 [--loud (default) | --quiet], where '--quiet' suppresses all output" $VALUE_ERROR
    fi
}

# Install essential build dependencies: CA-Certificates, cURL, and GNUPG.
#
# Parameters:
#   None.
#
install_build_dependencies() {
    # Update package list.
    apt-get update &&

    # Install CA-Certificates, cURL and GNUPG.
    apt-get --no-install-recommends -y install ca-certificates curl gnupg &&

    report "CA-Certificates, cURL and GNUPG were successfully installed"
}

# Install Node.js and NPM.
#
# Parameters:
#   major_version (int): The major version of Node.js to install.
#
install_node_js() {
    local major_version=$1

    # Check major version.
    if ! [ "$major_version" -eq "$REQUIRED_NODE_VERSION" ]; then
        error "invalid Node.js major version '$major_version' (expected '$REQUIRED_NODE_VERSION')" $VALUE_ERROR
    fi

    local keyring_dir="/etc/apt/keyrings"
    local gpg_key_url="https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
    local sources_list="/etc/apt/sources.list.d/nodesource.list"
    local node_repo_url="https://deb.nodesource.com/node_${major_version}.x"

    # Create keyring directory.
    mkdir -p "$keyring_dir" &&

    # Download Node.js GPG key and add it to the keyring.
    curl -fsSL "$gpg_key_url" | gpg --dearmor -o "${keyring_dir}/nodesource.gpg" &&

    # Add Node.js repository to sources list.
    echo "deb [signed-by=${keyring_dir}/nodesource.gpg] $node_repo_url nodistro main" | \
    tee "$sources_list" &&

    # Install Node.js and NPM (will be later removed).
    apt-get -y install nodejs npm

    # Check if Node.js was successfully installed.
    if ! command -v node &>/dev/null; then
        error "failled installing Node.js" $UNKNOWN_ERROR
    fi

    report "node.js version $NODE_VERSION was successfully installed"
}

# Install PNPM.
#
# Parameters:
#   major_version (int): The major version of PNPM to install.
#
install_pnpm() {
    local major_version=$1

    # Check if PNPM major version is 8.
    if ! [ "$major_version" -eq "$REQUIRED_PNPM_VERSION" ]; then
        error "invalid PNPM major version '$major_version' (expected '$REQUIRED_PNPM_VERSION')" $VALUE_ERROR
    fi

    npm i -g "pnpm@${major_versio}"

    # Check if PNPM was successfully installed.
    if ! command -v pnpm &>/dev/null; then
        error "failled installing PNPM" $UNKNOWN_ERROR
    fi

    report "PNPM version $PNPM_VERSION was successfully installed"
}

# Uninstall unnecessary dependencies: cURL, and GNUPG.
#
# Parameters:
#   None.
#
uninstall_unnecessary_dependencies() {
    apt-get -y autoremove curl gnupg npm &&
    apt-get -y autoclean &&
    rm -rf /var/lib/apt/lists/* &&
    report "uninstalled cURL, GNUPG and NPM successfully"
}

# Create a new group with the specified name.
#
# Parameters:
#   name (str): The name of the group to create.
#
create_group() {
    local name="$1"

    # Check if the group name is already in-use.
    if getent group "$name" &>/dev/null; then
        error "group name '$name' is already in-use" $VALUE_ERROR
    fi

    # Check if the group was succesfully created.
    if ! groupadd "$name"; then
        error "failed creating group '$name'" $UNKNOWN_ERROR
    fi

    report "group '$name' was successfully created"
}

# Add a new user to a specified group.
#
# Parameters:
#   group (str): The name of the group to add the user to.
#   name (str): The name of the user to create.
#   shell (str): The user's shell (e.g., "/bin/bash").
#
add_user() {
    local group="$1"
    local name="$2"
    local shell="$3"

    # Check if the group exists.
    if ! getent group "$group" &>/dev/null; then
        error "group '$group' does not exist" $VALUE_ERROR
    fi

    # Check if the user already exists in the group.
    if id "$name" >/dev/null 2>&1 && groups "$name" | grep -q "\b$group\b" >/dev/null 2>&1; then
        error "user '$name' already exists in group '$group'" $VALUE_ERROR
    fi

    # Check if the shell exists.
    if ! which "$shell" &>/dev/null; then
        error "shell '$shell' does not exist" $VALUE_ERROR
    fi

    # Check if the user was successfully created.
    if ! useradd -g "$group" -m -s "$shell" "$name"; then
        error "failed adding user '$name' to group '$group'" $UNKNOWN_ERROR
    fi

    local home="/home/$name"

    # Customize shell promt prefix for the user.
    echo PS1=\"\\e[32m$group\\e[0m ⟶ \\e[34m\\w\\e[0m \\$ \" >> $home/.bashrc &&

    # Create workspaces directory for the user.
    mkdir -p $home/workspaces &&

    # Save Node.js version in an environment variable.
    echo "NODE_VERSION=$(node -v | sed 's/v//')" >> $home/.bashrc &&

    # Save PNPM version in an environment variable.
    echo "PNPM_VERSION=$(pnpm -v)" >> $home/.bashrc &&

    report "user '$name' was successfully added to group '$group'"
}

# Delete a file if it exists.
#
# Parameters:
#   file (str): The path to the file to delete.
#
delete_file() {
    local file="$1"

    rm -f "$file" &&
    report "file '$file' successfully deleted"
}

# Execute the main setup process.
#
# Parameters:
#   None
#
main() {
    local self="$0"
    local mode="${1-"--loud"}"

    check_bash_version "$REQUIRED_BASH_VERSION" &&
    enable_mode "$mode" &&
    install_build_dependencies &&
    install_node_js "$NODE_MAJOR_VERSION" &&
    install_pnpm "$PNPM_MAJOR_VERSION" &&
    uninstall_unnecessary_dependencies &&
    create_group "$GROUP_NAME" &&
    add_user "$GROUP_NAME" "$USERNAME" "$SHELL" &&
    delete_file "$self"
}


# Entrypoint:
main "$@"
