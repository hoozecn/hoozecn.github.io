#!/bin/bash
set -e

cd $(dirname $0)

if [ -f token ]; then
    export CI_TOKEN=$(cat token)
fi

rm -rf _site && mkdir -p _site

pushd _site
  rm -rf .git
  git init
  
  git remote add origin https://hoozecn:$CI_TOKEN@github.com/hoozecn/hoozecn.github.io
  git config user.name bot-travis-ci
  git config user.email bot@traivs-ci.com
  git fetch origin --depth=10
  git checkout origin/master -b master

  pushd ..
    jekyll build
  popd

  git add -A
  git commit --allow-empty -am 'update'
  git push origin master:master
  (cd .. && jekyll clean)
popd
