/*!
 * Vitality v2.0.0 (http://themes.startbootstrap.com/vitality-v2.0.0)
 * Copyright 2013-2017 Start Bootstrap
 * Purchase a license to use this theme at (https://wrapbootstrap.com)
 */
/*!
 * Vitality v2.0.0 (http://themes.startbootstrap.com/vitality-v2.0.0)
 * Copyright 2013-2017 Start Bootstrap
 * Purchase a license to use this theme at (https://wrapbootstrap.com)
 */

// Load WOW.js on non-touch devices
var isPhoneDevice = "ontouchstart" in document.documentElement;
$(document).ready(function() {
    if (isPhoneDevice) {
        //mobile
    } else {
        //desktop               
        // Initialize WOW.js
        wow = new WOW({
            offset: 50
        })
        wow.init();
    }
});

(function($) {
    "use strict"; // Start of use strict

    // Collapse the navbar when page is scrolled
    $(window).scroll(function() {
        if ($("#mainNav").offset().top > 100) {
            $("#mainNav").addClass("navbar-shrink");
        } else {
            $("#mainNav").removeClass("navbar-shrink");
        }
    });

    // Activate scrollspy to add active class to navbar items on scroll
    $('body').scrollspy({
        target: '#mainNav',
        offset: 68
    });

    // Smooth Scrolling: Smooth scrolls to an ID on the current page
    // To use this feature, add a link on your page that links to an ID, and add the .page-scroll class to the link itself. See the docs for more details.
    $('a.page-scroll').bind('click', function(event) {
        var $anchor = $(this);
        $('html, body').stop().animate({
            scrollTop: ($($anchor.attr('href')).offset().top - 68)
        }, 1250, 'easeInOutExpo');
        event.preventDefault();
    });

    // Closes responsive menu when a link is clicked
    $('.navbar-collapse>ul>li>a, .navbar-brand').click(function() {
        $('.navbar-collapse').collapse('hide');
    });

    // Activates floating label headings for the contact form
    $("body").on("input propertychange", ".floating-label-form-group", function(e) {
        $(this).toggleClass("floating-label-form-group-with-value", !!$(e.target).val());
    }).on("focus", ".floating-label-form-group", function() {
        $(this).addClass("floating-label-form-group-with-focus");
    }).on("blur", ".floating-label-form-group", function() {
        $(this).removeClass("floating-label-form-group-with-focus");
    });

    // Owl Carousel Settings
    $(".team-carousel").owlCarousel({
        items: 3,
        navigation: true,
        pagination: false,
        navigationText: [
            "<i class='fa fa-angle-left'></i>",
            "<i class='fa fa-angle-right'></i>"
        ],
    });

    $(".portfolio-carousel").owlCarousel({
        singleItem: true,
        navigation: true,
        pagination: false,
        navigationText: [
            "<i class='fa fa-angle-left'></i>",
            "<i class='fa fa-angle-right'></i>"
        ],
        autoHeight: true,
        mouseDrag: false,
        touchDrag: false,
        transitionStyle: "fadeUp"
    });

    $(".testimonials-carousel, .mockup-carousel").owlCarousel({
        singleItem: true,
        navigation: true,
        pagination: true,
        autoHeight: true,
        navigationText: [
            "<i class='fa fa-angle-left'></i>",
            "<i class='fa fa-angle-right'></i>"
        ],
        transitionStyle: "backSlide"
    });

    $(".portfolio-gallery").owlCarousel({
        items: 3,
    });

    // Magnific Popup jQuery Lightbox Gallery Settings
    $('.gallery-link').magnificPopup({
        type: 'image',
        gallery: {
            enabled: true
        },
        image: {
            titleSrc: 'title'
        }
    });

    // Magnific Popup Settings
    $('.mix').magnificPopup({
        type: 'image',
        image: {
            titleSrc: 'title'
        }
    });

    // Vide - Video Background Settings
    $('header.video').vide({
        mp4: "mp4/camera.mp4",
        poster: "img/agency/backgrounds/bg-mobile-fallback.jpg"
    }, {
        posterType: 'jpg'
    });

})(jQuery); // End of use strict
