$(function() {

    $('#example').css('height', $('#main_content_wrap').width() * 0.435 + 'px');

    $('a#demo_banner').click(function() {
        if ($('#example').hasClass('visible')) {
            return hideExample();
        }
        showExample();
    });

    $('a#info').click(function() {
        console.log('clicked');
        if ($('a#info').hasClass('visible')) {
            $('.info').hide(500);
            return $('a#info').html('more info?').removeClass('visible');
        }
        $('.info').show(1000);
        $('a#info').html('less info').addClass('visible');
    });
});

function showExample() {
    $('#example').addClass('visible');
    $('#demo_banner').addClass('open');
    $('#example').slideDown(500);
    $('html, body').animate({
            scrollTop: $('#example').offset().top
    }, 1000);
}

function hideExample() {
    $('#example').removeClass('visible');
    $('#demo_banner').removeClass('open');
    $('#example').slideUp(1000);
    $('html, body').animate({ scrollTop: 0 }, 1000);
}
