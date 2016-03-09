# sweetroll [![unlicense](https://img.shields.io/badge/un-license-green.svg?style=flat)](http://unlicense.org)

A website engine for [the indie web] with curved swords. *Curved! Swords!*

- uses [Git]+[JSON] for storage
- supports [Micropub] for posting
- allows posting in [CommonMark Markdown] and other markup languages (powered by [Pandoc])
- sends and receives [Webmentions]
- supports the webmention-to-[syndication] / Syndicate by Reference process ([Bridgy Publish])
- sends [PubSubHubbub] notifications on new posts (for [readers])
- supports [indie-config]
- has a [JSON Web Tokens]-based [token-endpoint]
- written in [Haskell]

I'm running it on [my website](https://unrelenting.technology).

*Privacy notice*: if you expose your website's **git repo** publicly, your "deleted" entries are not really deleted.

[the indie web]: https://indiewebcamp.com
[Git]: https://git-scm.com
[JSON]: http://json.org
[JSON Web Tokens]: http://jwt.io
[CommonMark Markdown]: http://commonmark.org
[Pandoc]: http://johnmacfarlane.net/pandoc/
[Haskell]: http://haskell.org

[Micropub]: https://indiewebcamp.com/micropub
[Webmentions]: https://indiewebcamp.com/webmention
[syndication]: https://indiewebcamp.com/POSSE
[Bridgy Publish]: https://brid.gy/about#publishing
[PubSubHubbub]: https://indiewebcamp.com/PubSubHubbub
[readers]: https://indiewebcamp.com/readers
[indie-config]: https://indiewebcamp.com/indie-config
[token-endpoint]: https://indiewebcamp.com/token-endpoint

## Usage

*Installing Sweetroll on a server requires some UNIX sysadmin skills. If you can't do it, ask your friends for help or check out [other IndieWeb projects](https://indiewebcamp.com/projects): some of them have hosted versions, some run on shared PHP hosting.*

First, you need to get a binary of Sweetroll.
I haven't uploaded any yet, so you have to build from source.

### Buliding from source

- get [stack] \(from your OS package manager or `cabal install stack`)
- get [bower] \(get node/[npm](https://www.npmjs.com) from your OS package manager, `npm install -g bower`)
- `git clone` the repo
- `cd` into it
- `bower install`
- `stack build`

When it's done, it says where it put the binary (something like `.stack-work/install/your-platform/some/versions/.../bin`).

### Running on a server

Copy the binary to the server (using `scp`, usually).

Create a user account on the server (for example, `sweetroll`).

Create a directory where your website's content files will be, and run `git init` there.

Make sure the user has read and write permissions on the directory.

And configure your favorite service management program (don't forget to replace everything with your values!) to run Sweetroll as that user!

Here's an example for [runit](http://smarden.org/runit/index.html):

```bash
#!/bin/sh

umask g+w
exec chpst -u sweetroll /home/sweetroll/.local/bin/sweetroll
        --https \ # this means HTTPS is *working*! i.e. you have it set up on your reverse proxy!
        --protocol=unix \ # will run on /var/run/sweetroll/sweetroll.sock by default; you can override with --socket
  # or: --protocol=http --port=3030 \
        --domain=unrelenting.technology \ # your actual domain!
        --repo="/home/sweetroll/repo" \ # the site directory! don't forget to run `git init` inside of it first
        --secret="GENERATE YOUR LONG PSEUDORANDOM VALUE!...2MGy9ZkKgzexRpd7vl8" 2>&1
```

(Use something like `head -c 1024 < /dev/random | openssl dgst -sha512` to get the random value for the `secret`. No, not dynamically in the script. Copy and paste the value into the script. Otherwise you'll be logged out on every restart.)

Putting a reverse proxy in front of Sweetroll is not *required*, but you might want to run other software at different URLs, etc.
I wrote [443d](https://github.com/myfreeweb/443d) as a lightweight alternative to nginx.

After you start Sweetroll, open your new website.
It should write the default configuration to `conf/sweetroll.json` in your site directory.
Edit that file, you probably want to change some options.

Create a `templates` directory in your site directory.
You can override the HTML templates you see in this repo's `templates` directory with your own using your `templates` directory.
The templating engine is embedded JavaScript via [lodash](http://lodash.com)'s `_.template`.
You need to put your h-card and rel-me markup into `templates/author.ejs`.

Restart Sweetroll after any changes to the config file or the templates.

Use Micropub clients like [Micropublish](https://micropublish.herokuapp.com) and [Quill](https://quill.p3k.io) to post.

## Development

Use [stack] to build (and [bower] to get front-end dependencies).  
Use ghci to run tests and the server while developing (see the `.ghci` file).

The `:serve` command in ghci runs the server in test mode, which means you don't need to authenticate using IndieAuth.

```bash
$ bower install

$ stack build

$ stack test && rm tests.tix

$ (mkdir /tmp/sroll && cd /tmp/sroll && git init)

$ stack ghci --ghc-options="-fno-hpc"
:serve

$ http -f post localhost:3000/login | sed -Ee 's/.*access_token=([^&]+).*/\1/' > token

$ http -f post localhost:3000/micropub "Authorization: Bearer $(cat token)" h=entry content=HelloWorld
```

(the `http` command in the examples is [HTTPie](https://github.com/jkbrzt/httpie))


## Libraries I made for this project

- [gitson](https://github.com/myfreeweb/gitson), a git-backed storage engine
- [pcre-heavy](https://github.com/myfreeweb/pcre-heavy), a usable regular expressions library
- [http-link-header](https://github.com/myfreeweb/http-link-header), a parser for the Link header (RFC 5988)
- [microformats2-parser](https://github.com/myfreeweb/microformats2-parser), a Microformats 2 parser
- [indieweb-algorithms](https://github.com/myfreeweb/indieweb-algorithms), a collection of implementations of algorithms like [authorship](http://indiewebcamp.com/authorship) and link discovery
- [hs-duktape](https://github.com/myfreeweb/hs-duktape), Haskell bindings to [duktape](http://duktape.org), a lightweight ECMAScript (JavaScript) engine

## TODO

- html/frontend/templating
  - [x] flexible index/category pages
  - [x] merging category slices
  - [x] new index page layout: like switching between filters on Twitter profiles
  - [ ] ?? prev/next navigation + combined categories == kinda weird...
  - [ ] Atom feed (should be followable from [GNU Social](https://indiewebcamp.com/GNU_social) i.e. should be PubSubHubbub'd, should be based on HTML as the source of truth)
  - [ ] support [WebFinger](https://webfinger.net) with HTML as the source of truth as well (but also additional links from config e.g. for [remoteStorage](https://remotestorage.io))
  - [x] better note like display ("Liked a note by User Name" then gray smaller quote, like in Twitter notifications)
  - [x] more consistency / abstraction with cite contexts, etc.
  - [ ] figure out URL/canonical/etc. handling for alternative networks & mirrors like .onion & IPFS -- including webmentions!
  - [ ] custom non-entry html pages
  - [ ] archive pages, ie. unpaginated pages (basically `?after=0&before=9223372036854775807` but... "archive" design?)
  - [ ] proxying reply-context and comments-presentation images (to avoid mixed content and possible tracking) (note: we already depend on `JuicyPixels` through Pandoc)
  - [ ] indieweb-components: a component for a Medium-style popup on selection that offers a fragmention link and (?) indie-config repost-quote-something (look how [selection-sharer](https://github.com/xdamman/selection-sharer) works on mobile!! but probably should look the same just at the opposite direction than iOS's popup)
  - [x] a pool of hs-duktape instances for template rendering!
  - [ ] built-in TLS server, since we depend on `tls` already because of the client
- [ ] event system: hooks on micropub posting and webmention processing
  - [ ] cleaning a cache (which is not there yet... should be an in-process cache with fast expiration -- protection against DDoS or Hacker News effect)
  - [ ] real-time page updates with Server-Sent Events (make a Web Component for HTML-based updating)
  - [ ] JS hooks as plugins (API: a Sweetroll object which is an EventEmitter and also has config/secrets getters; should be possible to make HTTP requests to e.g. send webmention notifications)
    - [ ] Telegram bot (posting, webmention notifications, webmention deletion, etc.) as JS plugin (so, API also needs to allow handling HTTP requests)
  - [ ] static mode: on these events, regenerate website pages into static HTML files
    - [ ] IPFS support! (see/improve [hs-ipfs-api](https://github.com/davidar/hs-ipfs-api)) publishing there in the event handler too. Oh, and [IPFS supports custom services](https://ipfs.io/ipfs/QmTkzDwWqPbnAh5YiV5VwcTLnGdwSNsNTn2aDxdXBFca7D/example#/ipfs/QmQwAP9vFjbCtKvD8RkJdCvPHqLQjZfW7Mqbbqx18zd8j7/api/service/readme.md)! IPFS-Webmention, because why not.
    - [ ] S3 support & running on AWS Lambda... or good old CGI, which is actually kinda similar to Lambda
- webmention ([YAY W3C DRAFT](http://webmention.net/draft/)!)
  - [ ] stop using pandoc walk for finding urls
  - [ ] hashcash
    - [ ] throttle non-hashcashed requests to avoid [DDoS](https://indiewebcamp.com/DDOS)
  - [ ] moderation tools
    - [ ] different modes in config: allow all (except blocked), allow known good domains (e.g. domains replied to), premoderate all, turn off webmention
    - [ ] [blocking](https://indiewebcamp.com/block) domains
      - [ ] sharing block lists
  - [ ] reverify/refetch to update user profiles and stuff
  - [ ] send [salmentions](https://indiewebcamp.com/Salmention)
  - [ ] deduplicate threaded replies like [there](https://unrelenting.technology/replies/2015-09-06-20-29-54) (that one is formatted as a reply both to my post and to the reply)
- micropub ([YAY W3C DRAFT](http://micropub.net/draft/)!)
  - [ ] handle update requests
  - [ ] handle delete requests
  - [ ] handle undelete requests
  - [ ] editing interface: when logged in, display a (Polymer-based) Web Component *on the site* that shows a top panel, overlays edit/remove buttons on top of microformats entries (including replies!), submits edits/deletes over micropub, (actually make that extensible, micropub+microformats as just one supported thing)
    - [ ] microadmin/microsettings/what's-a-good-name: extension to micropub for site settings. `?q=settings-schema` to get [JSON Schema](http://json-schema.org) of settings, display the form, `{mp-action: settings}` to update
    - [ ] markup formats support (`rel=alternate` for getting the source, field like `content[markdown]` for submitting) and `?q=markup-formats`
  - [x] respond to `?q=syndicate-to` with JSON
  - [x] respond to `?q=source`
  - [ ] support posting [photos](https://indiewebcamp.com/photos)
- [ ] indieweb-algorithms: [mf2-shim](https://github.com/indieweb/php-mf2-shim) style functionality!
- [ ] indieweb-algorithms?: ensure the person you're replying to *never* gets picked up you when you're replying (caught in test without own h-card)
- [ ] something about [search](https://indiewebcamp.com/search) ([full-text-search](https://hackage.haskell.org/package/full-text-search) i guess)
- [ ] tags? (hmm could just rely on search instead of keeping exact indexes)
- [ ] extract `formToObject` from `Sweetroll.Micropub.Request` into a separate library

## License

This is free and unencumbered software released into the public domain.  
For more information, please refer to the `UNLICENSE` file or [unlicense.org](http://unlicense.org).

[stack]: https://github.com/commercialhaskell/stack
[bower]: http://bower.io
