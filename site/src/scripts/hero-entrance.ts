  (function () {
    var counter = document.querySelector('.hero .counter');
    var frame = document.querySelector('.hero-frame');
    if (!counter || !frame) return;

    var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var target = parseInt(counter.getAttribute('data-target') || '0', 10);

    if (reduceMotion) return;

    document.documentElement.classList.add('hero-animate');

    var start = null;
    var duration = 900;
    counter.textContent = '0';

    function step(timestamp) {
      if (start === null) start = timestamp;
      var progress = Math.min((timestamp - start) / duration, 1);
      var eased = 1 - Math.pow(1 - progress, 3);
      counter.textContent = String(Math.round(eased * target));
      if (progress < 1) {
        window.requestAnimationFrame(step);
      } else {
        counter.textContent = String(target);
      }
    }

    window.requestAnimationFrame(function () {
      document.documentElement.classList.add('hero-ready');
      window.requestAnimationFrame(step);
    });
  })();
