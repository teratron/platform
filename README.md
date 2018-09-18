# platform

# NodeJS

npm install

# создает файл package.json, который содержит информацию о проекте (описание проекта и зависимости).
npm init

     ---> package.json

# Gulp
https://habr.com/post/250569/

npm install --global gulp

npm install gulp -g

npm install gulp-cli -g

npm install gulp --save-dev

     ---> gulpfile.js

npm install gulp-sass --save-dev

var gulp = require('gulp');
var sass = require('gulp-sass');

# Bower
http://nano.sapegin.ru/all/bower

npm install bower -g

bower init

     ---> bower.json

bower install --save jquery  # Или bower i -S jquery

Для удаления пакетов используется команда bower uninstall:

bower uninstall --save jquery-icheck  # Или bower un -S jquery-icheck

Команда bower install (без дополнительных параметров) вернёт всё как было:

bower install