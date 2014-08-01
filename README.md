# RethinkDB News Reader Demo

This application is a simple cloud-based news reader that supports RSS and Atom. The back-end, which is built with Sinatra, stores the user's feeds in RethinkDB. The application uses [Feedjira](https://github.com/feedjira/feedjira) to parse feeds and [sucker_punch](https://github.com/brandonhilkert/sucker_punch) to perform periodic background updates. The front-end is a single-page web application built with AngularJS.
