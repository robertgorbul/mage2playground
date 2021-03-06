#!/bin/bash

[[ "${DEBUG}" = "true" ]] && set -x

# Ensure our Magento directory exists
mkdir -p "${MAGENTO_ROOT}"

if [[ -n "${MAGE2_INSTALL_PARAMS}" ]]; then
  echo "Run Composer install..."
  composer install
  echo "Composer installation complete!"
  chmod u+x bin/magento

  # Use separate regexp's to eliminate unexpected behaviour
  MAGE2_INSTALL_PARAMS=$(sed -E -e "s/^[\"\']//" -e "s/[\"\']$//" <<< "${MAGE2_INSTALL_PARAMS}")

  echo "Mage2 installation started..."
  INSTALL_CMD="magento setup:install ${MAGE2_INSTALL_PARAMS}"

  ${INSTALL_CMD}

  if [[ "${MAGE2_VARNISH_FPC}" = "true" ]]; then
    magento config:set --scope=default --scope-code=0 system/full_page_cache/caching_application 2
    magento setup:config:set --http-cache-hosts=varnish
  fi

  echo "Configure Redis..."
  magento setup:config:set --cache-backend=redis \
    --cache-backend-redis-server=rediscache \
    --cache-backend-redis-db=0

  magento setup:config:set --page-cache=redis \
    --page-cache-redis-server=rediscache \
    --page-cache-redis-db=1

  magento setup:config:set --session-save=redis \
    --session-save-redis-host=redissession \
    --session-save-redis-log-level=3 \
    --session-save-redis-db=2

  if [[ "${MAGE2_USE_SAMPLE_DATA}" = "true" ]]; then
    magento sampledata:deploy
    magento setup:upgrade
    magento setup:di:compile
    magento setup:static-content:deploy -f
    magento cache:flush
  fi

  echo "Update permissions..."
  find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} +
  find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} +

  echo "Mage2 installation complete!"
else
  echo "Skipping Mage2 installation..."
fi
