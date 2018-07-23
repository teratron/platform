//
$(document).ready(function () {

});

// this function includes all necessary js files for the application
function include(file) {
    var script   = document.createElement('script');
    script.src   = file;
    script.type  = 'text/javascript';
    script.defer = true;

    document.getElementsByTagName('head').item(0).appendChild(script);
    //document.body.insertAdjacentHTML('beforeEnd','script');
    //document.body.appendChild(script);
}

// include any js files here
include('js/less.min.js');
include('js/prefixes.js');
include('js/jquery.min.js');
include('js/jquery.cookie.js');



//onclick="window.location.href='https://'"

