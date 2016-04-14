* Unit testing
* Document multi-database setup.
* Change (and don't release!) the session secret key before deployment.
* Respond with 404 on invalid deletes (and some other operations?)
* Add useful scopes to WebUsers
* Handle concurrency issues with Web users.
* Change units on graphs:
  * All units should be in the form of rates (i.e. jobs/second or jobs/day) or averages.
  * Alternatively, the number of jobs could be measured at individual points rather than over
    entire days, or we could use a bar-style graph.
  * A bar-style graph might actually be best.
* Document mailer setup (at least source address needs to be configured.)
* Use #require instead of #permit on param hashes?
