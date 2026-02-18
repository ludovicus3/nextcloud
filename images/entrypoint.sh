#!/bin/sh
set -eu

# version_greater A B returns whether A > B
version_greater() {
  [ "$(printf '%s\n' "$@" | sort -t '.' -n -k1,1 -k2,2 -k3,3 -k4,4 | head -n 1)" != "$1" ]
}

# return true if specified directory is empty
directory_empty() {
  [ -z "$(ls -A "$1/")" ]
}

# Execute all executable files in a given directory in alphanumeric order
run_path() {
  local hook_folder_path="/docker-entrypoint-hooks.d/$1"
  local return_code=0
  local found=0

  echo "=> Searching for hook scripts (*.sh) to run, located in the folder \"${hook_folder_path}\""

  if ! [ -d "${hook_folder_path}" ] || directory_empty "${hook_folder_path}"; then
    echo "==> Skipped: the \"$1\" folder is empty (or does not exist)"
    return 0
  fi

  find "${hook_folder_path}" -maxdepth 1 -iname '*.sh' '(' -type f -o -type l ')' -print | sort | (
    while read -r script_file_path; do
      if ! [ -x "${script_file_path}" ]; then
        echo "==> The script \"${script_file_path}\" was skipped, because it lacks the executable flag"
        found=$((found-1))
        continue
      fi

      echo "==> Running the script (cwd: $(pwd)): \"${script_file_path}\""
      found=$((found+1))
      /bin/sh -c "${script_file_path}" || return_code="$?"

      if [ "${return_code}" -ne "0" ]; then
        echo "==> Failed at executing script \"${script_file_path}\". Exit code: ${return_code}"
        exit 1
      fi

      echo "==> Finished executing the script: \"${script_file_path}\""
    done
    if [ "$found" -lt "1" ]; then
      echo "==> Skipped: the \"$1\" folder does not contain any valid scripts"
    else
      echo "=> Completed executing scripts in the \"$1\" folder"
    fi
  )
}

# If another process is syncing the html folder, wait for
# it to be done, then escape initalization.
(
  if ! flock -n 9; then
    # If we couldn't get it immediately, show a message, then wait for real
    echo "Another process is initializing Nextcloud. Waiting..."
    flock 9
  fi

  installed_version="0.0.0.0"
  if [ -f /var/www/html/version.php ]; then
    # shellcheck disable=SC2016
    installed_version="$(php -r 'require "/var/www/html/version.php"; echo implode(".", $OC_Version);')"
  fi
  # shellcheck disable=SC2016
  image_version="$(php -r 'require "/usr/src/nextcloud/version.php"; echo implode(".", $OC_Version);')"

  if version_greater "$installed_version" "$image_version"; then
    echo "Can't start Nextcloud because the version of the data ($installed_version) is higher than the docker image version ($image_version) and downgrading is not supported. Are you sure you have pulled the newest image version?"
    exit 1
  fi

  if version_greater "$image_version" "$installed_version"; then
    echo "Initializing nextcloud $image_version ..."
    if [ "$installed_version" != "0.0.0.0" ]; then
      if [ "${image_version%%.*}" -gt "$((${installed_version%%.*} + 1))" ]; then
        echo "Can't start Nextcloud because upgrading from $installed_version to $image_version is not supported."
        echo "It is only possible to upgrade one major version at a time. For example, if you want to upgrade from version 14 to 16, you will have to upgrade from version 14 to 15, then from 15 to 16."
        exit 1
      fi
      echo "Upgrading nextcloud from $installed_version ..."
      php /var/www/html/occ app:list | sed -n "/Enabled:/,/Disabled:/p" > /tmp/list_before
    fi

    rsync_options="-rlD"
    rsync $rsync_options --delete --exclude-from=/upgrade.exclude /usr/src/nextcloud/ /var/www/html/
    for dir in config data custom_apps themes; do
      if [ ! -d "/var/www/html/$dir" ] || directory_empty "/var/www/html/$dir"; then
        rsync $rsync_options --include "/$dir/" --exclude '/*' /usr/src/nextcloud/ /var/www/html/
      fi
    done
    rsync $rsync_options --include '/version.php' --exclude '/*' /usr/src/nextcloud/ /var/www/html/

    # Install
    if [ "$installed_version" = "0.0.0.0" ]; then
      echo "New nextcloud instance"

      install=false
      if [ -n "${NEXTCLOUD_ADMIN_USER+x}" ] && [ -n "${NEXTCLOUD_ADMIN_PASSWORD+x}" ]; then
        # shellcheck disable=SC2016
        install_options="-n --admin-user \"$NEXTCLOUD_ADMIN_USER\" --admin-pass \"$NEXTCLOUD_ADMIN_PASSWORD\""
        if [ -n "${NEXTCLOUD_DATA_DIR+x}" ]; then
          # shellcheck disable=SC2016
          install_options=$install_options" --data-dir \"$NEXTCLOUD_DATA_DIR\""
        fi

        echo "Installing with PostgreSQL database"
        # shellcheck disable=SC2016
        install_options=$install_options" --database pgsql --database-name \"$POSTGRES_DB\" --database-user \"$POSTGRES_USER\" --database-pass \"$POSTGRES_PASSWORD\" --database-host \"$POSTGRES_HOST\""
        install=true

        if [ "$install" = true ]; then
          run_path pre-installation

          echo "Starting nextcloud installation"
          max_retries=10
          try=0
          until  [ "$try" -gt "$max_retries" ] || php /var/www/html/occ maintenance:install $install_options
          do
            echo "Retrying install..."
            try=$((try+1))
            sleep 10s
          done
          if [ "$try" -gt "$max_retries" ]; then
            echo "Installing of nextcloud failed!"
            exit 1
          fi
          if [ -n "${NEXTCLOUD_TRUSTED_DOMAINS+x}" ]; then
            echo "Setting trusted domains…"
            set -f # turn off glob
            NC_TRUSTED_DOMAIN_IDX=1
            for DOMAIN in ${NEXTCLOUD_TRUSTED_DOMAINS}; do
              DOMAIN=$(echo "${DOMAIN}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
              php /var/www/html/occ config:system:set trusted_domains $NC_TRUSTED_DOMAIN_IDX --value="${DOMAIN}"
              NC_TRUSTED_DOMAIN_IDX=$((NC_TRUSTED_DOMAIN_IDX+1))
            done
            set +f # turn glob back on
          fi

          run_path post-installation
        fi
      fi
      
      # not enough specified to do a fully automated installation 
      if [ "$install" = false ]; then 
        echo "Next step: Access your instance to finish the web-based installation!"
        echo "Hint: You can specify NEXTCLOUD_ADMIN_USER and NEXTCLOUD_ADMIN_PASSWORD and the database variables _prior to first launch_ to fully automate initial installation."
      fi
    # Upgrade
    else
      run_path pre-upgrade

      php /var/www/html/occ upgrade

      php /var/www/html/occ app:list | sed -n "/Enabled:/,/Disabled:/p" > /tmp/list_after
      echo "The following apps have been disabled:"
      diff /tmp/list_before /tmp/list_after | grep '<' | cut -d- -f2 | cut -d: -f1
      rm -f /tmp/list_before /tmp/list_after

      run_path post-upgrade
    fi

    echo "Initializing finished"
  fi

  # Update htaccess after init if requested
  if [ -n "${NEXTCLOUD_INIT_HTACCESS+x}" ] && [ "$installed_version" != "0.0.0.0" ]; then
    php /var/www/html/occ maintenance:update:htaccess
  fi
) 9> /var/www/html/nextcloud-init-sync.lock

# warn if config files on persistent storage differ from the latest version of this image
for cfgPath in /usr/src/nextcloud/config/*.php; do
  cfgFile=$(basename "$cfgPath")

  if [ "$cfgFile" != "config.sample.php" ] && [ "$cfgFile" != "autoconfig.php" ]; then
    if ! cmp -s "/usr/src/nextcloud/config/$cfgFile" "/var/www/html/config/$cfgFile"; then
      echo "Warning: /var/www/html/config/$cfgFile differs from the latest version of this image at /usr/src/nextcloud/config/$cfgFile"
    fi
  fi
done

run_path before-starting

exec "$@"