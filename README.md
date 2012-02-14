# FuzzyInfer

## setup

1. gem install a bleeding edge earth

    cd earth
    git pull
    gem build earth.gemspec
    gem install earth-0.11.10.gem --ignore-dependencies --no-rdoc --no-ri

2. create your test database

    mysql -u root -ppassword -e "create database test_fuzzy_infer charset utf8"

3. load cbecs (just the first time - note that it is hardcoded to ONLY run cbecs data_miner)

   RUN_DATA_MINER=true rake

## further testing

    rake

## Copyright

Copyright 2012 Brighter Planet, Inc.
