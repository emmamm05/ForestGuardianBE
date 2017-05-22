#!/usr/bin/env bash

function fg_activate_machine {
   eval $(docker-machine env forestguardian)
}

function fg_clean {
   fg_activate_machine
   docker-compose -f docker-compose-production.yml down
   docker volume rm $(docker volume ls -f dangling=true -q)
}

function fg_start {
    set -x
    fg_activate_machine
    cd containers/production
    # --build-arg CACHE_DATE=$(date) forces docker to build the image after a particular step.
    docker build --build-arg CACHE_DATE=$(date) -t forestguardian/backend .
    docker push forestguardian/backend
    cd ../..
    docker-compose -f docker-compose-production.yml build
    docker-compose -f docker-compose-production.yml up -d redis db
    # waits for database to be initialized.
    sleep 10
    # setup database
    RAILS_ENV=production docker-compose -f docker-compose-production.yml run web bundle exec rake db:create
    RAILS_ENV=production docker-compose -f docker-compose-production.yml run web bundle exec rake db:schema:load
    RAILS_ENV=production docker-compose -f docker-compose-production.yml run web bundle exec rake db:migrate
    RAILS_ENV=production docker-compose -f docker-compose-production.yml run web bundle exec rake db:seed
    # start services that depend on db
    docker-compose -f docker-compose-production.yml up -d sidekiq web
    set +x
}

function fg_quick_reload {
    tmp_start=$(date +%s) &&

    fg_activate_machine &&
    docker-compose -f docker-compose-production.yml exec web bundle exec bash -c 'git pull' &&
    docker-compose -f docker-compose-production.yml exec sidekiq bundle exec bash -c 'git pull' &&
    docker-compose -f docker-compose-production.yml restart sidekiq web &&

    tmp_end=$(date +%s)
    echo Quick Reload lasted $(( tmp_end - tmp_start )) seconds.
}

function fg_quick_precompile {
    tmp_start=$(date +%s) &&

    fg_activate_machine &&
    docker-compose -f docker-compose-production.yml exec web bundle exec bash -c 'bundle exec rake assets:precompile' &&
    docker-compose -f docker-compose-production.yml restart web &&

    tmp_end=$(date +%s)
    echo Quick Precompile lasted $(( tmp_end - tmp_start )) seconds.
}

function fg_quick_gem_install {
    tmp_start=$(date +%s) &&

    fg_activate_machine &&
    docker-compose -f docker-compose-production.yml exec web bundle exec bash -c 'bundle install' &&
    docker-compose -f docker-compose-production.yml exec sidekiq bundle exec bash -c 'bundle install' &&


    tmp_end=$(date +%s)
    echo Quick Gems Install lasted $(( tmp_end - tmp_start )) seconds.
}

function fg_reload {
    fg_activate_machine
    docker-compose -f docker-compose-production.yml stop web
    docker-compose -f docker-compose-production.yml build web
    docker-compose -f docker-compose-production.yml up -d web
}

function fg_ip {
    fg_activate_machine
    docker-machine ip forestguardian
}