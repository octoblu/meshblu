

/* -- Waypoints
   -- src: http://imakewebthings.com/jquery-waypoints/
   ---------------------------- */
$(document).ready(function() {

  $('#about, #testimonials, #pricing, #team').waypoint(function() {
    $('.feature').addClass('animated fadeInUp').css('display', 'block');
  }, { offset: 100 });

  $('#hobbies').waypoint(function() {
    $('.tip').addClass('animated bounceInUp').css('display', 'block');
  }, { offset: 0 });

  $('#home').waypoint(function() {
    $('.logo h1 a').removeClass('white');
  }, { offset: -100 });

  $('#about, #features, #pricing, featured-cta').waypoint(function() {
    $('.logo h1 a').addClass('white');
  }, { offset: 100 });

});





/* -- Page Slider
   -- src: https://github.com/davist11/jQuery-One-Page-Nav
   ---------------------------- */


$(document).ready(function() {

var $nav = $('.sidenav');

  $nav.onePageNav({
      currentClass: 'current',
      changeHash: false,
      scrollSpeed: 400,
      scrollOffset: 0,
      scrollThreshold: 0.5,
      filter: '',
      easing: 'swing',
      begin: function() {
          //I get fired when the animation is starting
      },
      end: function() {
          //I get fired when the animation is ending
      },
      scrollChange: function($currentListItem) {
          //I get fired when you enter a section and I pass the list item of the section
      }
  });



});




/* -- Botostrap Tooltip
   -- src: http://twitter.github.io/bootstrap/javascript.html#tooltips
   ---------------------------- */

$('.tip').tooltip({
  placement: 'top'
})




/* -- Magnific Popup (Responsive Lightbox)
   -- src: www.dimsemenov.com/plugins/magnific-popup
   ---------------------------- */

$(document).ready(function() {
$('.lightbox').magnificPopup({
  type: 'image',

  overflowY: 'auto',

  closeBtnInside: true,
  preloader: false,
  
  midClick: true,
  removalDelay: 100,
  mainClass: 'my-mfp-slide-bottom',

  image: {
    verticalFit: true
  }
});

$('.modal-form').magnificPopup({
  type: 'inline',
  preloader: false,
  focus: '#fullname',
  midClick: true,
  removalDelay: 300,
  mainClass: 'my-mfp-slide-bottom',

  // When elemened is focused, some mobile browsers in some cases zoom in
  // It looks not nice, so we disable it:
  callbacks: {
    beforeOpen: function() {
      if($(window).width() < 700) {
        this.st.focus = false;
      } else {
        this.st.focus = '#fullname';
      }
    }
  }
});

});




/* -- Bxslider
   -- src: www.bxslider.com
   ---------------------------- */

$(function(){

  $('.featuredSlider').bxSlider({
    auto: true,
    autoControls: false,
    mode: 'fade',
    easing: 'linear',
    pager: false,
    controls: true,
    speed: 150,
    pause: 7000
  });

});




/* -- Smooth Scroll to Specific Anchor
   -- src: https://github.com/kswedberg/jquery-smooth-scroll
------------------------- */

$('a.scroll, .logo a').smoothScroll({
  offset: 0,

  // one of 'top' or 'left'
  direction: 'top',

  // only use if you want to override default behavior
  scrollTarget: null,

  // fn(opts) function to be called before scrolling occurs.
  // `this` is the element(s) being scrolled
  beforeScroll: function() {},

  // fn(opts) function to be called after scrolling occurs.
  // `this` is the triggering element
  afterScroll: function() {},
  easing: 'swing',
  speed: 400,

  // coefficient for "auto" speed
  autoCoefficent: 2

});





/* -- Full Screen Viewport Container
   ---------------------------- */

$(function () {

      // Set Initial Screen Dimensions

      var screenWidth = $(window).width() + "px";
      var screenHeight = $(window).height() + "px";

      $("#home").css({
        width: screenWidth,
        height: screenHeight
      });

      // Every time the window is resized...

      $(window).resize( function () {

        // Fetch Screen Dimensions

        var screenWidth = $(window).width() + "px";
        var screenHeight = $(window).height() + "px";
        
        // Set Slides to new Screen Dimensions
        
        $("#home").css({
          width: screenWidth,
          height: screenHeight
        }); 
        
      });

  });

