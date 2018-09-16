// Not closeable dropdown menu
$('.keep-open').on({
    "shown.bs.dropdown": function() { $(this).attr('closable', false); },
    "click":             function() { },
    "hide.bs.dropdown":  function() { return $(this).attr('closable') == 'true'; }
});

$('.keep-open #dropdownBtnBag').on({
    "click": function() {
        $(this).parent().attr('closable', true );
    }
});

// Initialize Swiper
var swiper = new Swiper('.swiper-container', {
    slidesPerView: 3,
    centeredSlides: false,
    slidesOffsetAfter: 0,
    pagination: {
        el: '.swiper-pagination',
        clickable: true
    },
    navigation: {
        nextEl: '.swiper-button-next',
        prevEl: '.swiper-button-prev'
    }
});

// Product Viewer
var $thumb = $('.view-thumb');
var $slide = $('.view-slide');
var $pager = $('.view-page');

//$('.product-view').find('.active').removeClass('active');
$thumb.filter('.active').removeClass('active');
$slide.filter('.active').removeClass('active');
$pager.filter('.active').removeClass('active');

$thumb.eq(0).addClass('active');
$slide.eq(0).addClass('active');
$pager.eq(0).addClass('active');

$thumb.click(function() {
    swipeView($(this))
});
$pager.click(function() {
    swipeView($thumb.eq($(this).index()))
});

function swipeView($obj) {
    if(!$obj.is('.active')) {
        var $thumb = $('.view-thumb');
        var $slide = $('.view-slide');
        var $pager = $('.view-page');
        var i = $thumb.filter('.active').index();

        $thumb.eq(i).removeClass('active');
        $slide.eq(i).removeClass('active');
        $pager.eq(i).removeClass('active');

        i = $obj.index();
        $slide.eq(i).addClass('active');
        $pager.eq(i).addClass('active');
        $obj.addClass('active');
    }
}

//
$('.quantity-switcher > .counter-minus').click(function() {
    changeQuantity(-1);
});
$('.quantity-switcher > .counter-plus').click(function() {
    changeQuantity(1);
});
//
function changeQuantity(cnt) {
    var tag = $('.quantity-switcher > .counter');
    var qty = parseInt(tag.html(), 10) + cnt;
    if(qty > 0 && qty < 100) tag.text(qty);
}

$('.btn-menu').on('click', function (e) {
    e.preventDefault();
    $(this).toggleClass('active');
    $(this).next().slideToggle();
});