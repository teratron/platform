﻿var gulp         = require('gulp'), // Подключаем Gulp
    less         = require('gulp-less'), //Подключаем Less пакет,
    sass         = require('gulp-sass'), //Подключаем Sass пакет,
    cssnano      = require('gulp-cssnano'), // Подключаем пакет для минификации CSS
    sourcemaps   = require('gulp-sourcemaps'),
    rename       = require('gulp-rename'), // Подключаем библиотеку для переименования файлов
    browsersync  = require('browser-sync'), // Подключаем Browser Sync
    concat       = require('gulp-concat'), // Подключаем gulp-concat (для конкатенации файлов)
    uglify       = require('gulp-uglifyjs'), // Подключаем gulp-uglifyjs (для сжатия JS)
    del          = require('del'), // Подключаем библиотеку для удаления файлов и папок
    imagemin     = require('gulp-imagemin'), // Подключаем библиотеку для работы с изображениями
    pngquant     = require('imagemin-pngquant'), // Подключаем библиотеку для работы с png
    cache        = require('gulp-cache'), // Подключаем библиотеку кеширования
    autoprefixer = require('gulp-autoprefixer');// Подключаем библиотеку для автоматического добавления префиксов

gulp.task('less', function() {
    return gulp.src('dev/less/+(platform|theme).less')
    //return gulp.src('source-files')
        .pipe(less()) // Using gulp-less
        .pipe(autoprefixer(['last 15 versions', '> 1%', 'ie 8', 'ie 7'], { cascade: true })) // Создаем префиксы
        .pipe(gulp.dest('dev/css')); // Выгружаем результата в папку dev/css
});

gulp.task('sass', function(){ // Создаем таск Sass
    return gulp.src('dev/sass/**/*.sass') // Берем источник
        .pipe(sass()) // Преобразуем Sass в CSS посредством gulp-sass
        .pipe(autoprefixer(['last 15 versions', '> 1%', 'ie 8', 'ie 7'], { cascade: true })) // Создаем префиксы
        .pipe(gulp.dest('dev/css')) // Выгружаем результата в папку dev/css
        .pipe(browsersync.reload({stream: true})); // Обновляем CSS на странице при изменении
});

gulp.task('browser-sync', function() { // Создаем таск browser-sync
    browsersync({ // Выполняем browsersync
        server: { // Определяем параметры сервера
            baseDir: 'build' // Директория для сервера - dev
        },
        notify: false // Отключаем уведомления
    });
});

gulp.task('scripts', function() {
    return gulp.src([ // Берем все необходимые библиотеки
        'dev/libs/jquery/build/jquery.min.js', // Берем jQuery
        'dev/libs/magnific-popup/build/jquery.magnific-popup.min.js' // Берем Magnific Popup
    ])
        .pipe(concat('libs.min.js')) // Собираем их в кучу в новом файле libs.min.js
        .pipe(uglify()) // Сжимаем JS файл
        .pipe(gulp.dest('dev/js')); // Выгружаем в папку dev/js
});

gulp.task('css-libs', ['less', 'sass'], function() {
    return gulp.src('dev/css/+(platform|theme).css') // Выбираем файл для минификации
        .pipe(sourcemaps.init())
        .pipe(cssnano()) // Сжимаем
        .pipe(rename({suffix: '.min'})) // Добавляем суффикс .min
        .pipe(sourcemaps.write('.'))
        .pipe(gulp.dest('dev/css')); // Выгружаем в папку dev/css
});

gulp.task('watch', ['browser-sync', 'css-libs', 'scripts'], function() {
    gulp.watch('dev/less/**/*.less', ['less']); // Наблюдение за less файлами в папке less
    gulp.watch('dev/sass/**/*.sass', ['sass']); // Наблюдение за sass файлами в папке sass
    gulp.watch('dev/*.html', browsersync.reload); // Наблюдение за HTML файлами в корне проекта
    gulp.watch('dev/js/**/*.js', browsersync.reload);   // Наблюдение за JS файлами в папке js
});

gulp.task('clean', function() {
    return del.sync('build'); // Удаляем папку build перед сборкой
});

gulp.task('img', function() {
    return gulp.src('dev/images/**/*') // Берем все изображения из dev
        .pipe(cache(imagemin({ // С кешированием
            // .pipe(imagemin({ // Сжимаем изображения без кеширования
            interlaced: true,
            progressive: true,
            svgoPlugins: [{removeViewBox: false}],
            use: [pngquant()]
        }))/**/)
        .pipe(gulp.dest('build/images')); // Выгружаем на продакшен
});

gulp.task('build', ['clean', 'img', 'less', 'sass', 'scripts'], function() {
    var buildCss = gulp.src([ // Переносим библиотеки в продакшен
        //'dev/css/platform.css',
        'dev/css/platform.min.css',
        //'dev/css/theme.css',
        'dev/css/theme.min.css'
    ])
        .pipe(gulp.dest('build/css'));

    var buildFonts = gulp.src('dev/fonts/**/*') // Переносим шрифты в продакшен
        .pipe(gulp.dest('build/fonts'));

    var buildJs = gulp.src('dev/js/**/*') // Переносим скрипты в продакшен
        .pipe(gulp.dest('build/js'));

    var buildHtml = gulp.src('dev/**/*.html') // Переносим HTML в продакшен
        .pipe(gulp.dest('build'));

    var buildPhp = gulp.src('dev/**/*.php') // Переносим PHP в продакшен
        .pipe(gulp.dest('build'));
});

gulp.task('clear', function (callback) {
    return cache.clearAll();
});

gulp.task('default', ['watch']);