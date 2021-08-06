[![CodeFactor](https://www.codefactor.io/repository/github/oaeproject/oae-demo/badge/master)](https://www.codefactor.io/repository/github/oaeproject/oae-demo/overview/master)
[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Foaeproject%2Foae-demo.svg?type=shield)](https://app.fossa.com/projects/git%2Bgithub.com%2Foaeproject%2Foae-demo?ref=badge_shield)

# How to get OAE running with docker

## Run built image from dockerhub

```bash
docker run --rm -it -P --network host --name=oae oaeproject/oae-demo:latest
```

You'll still need to set up the dns entries, as follows:

```bash
# As root or with sudo
echo "127.0.0.1 admin.oae.com" > /etc/hosts
echo "127.0.0.1 guest.oae.com" > /etc/hosts
```

As soon as the container boot, you may go to `admin.oae.com` (admin interface) or `guest.oae.com` (test tenant).

## Build and run locally

```bash
# Build the image
docker build --rm -t oae-demo:latest -f Dockerfile .
# Run the container (all servers)
docker run --rm -it -P --network host --name=oae oae-demo:latest
```

This is intended to work on linux alone.

## Debug locally

After building the image locally, try running the container with `bin/bash` like this:

```
docker run --rm -it -P --network host --name=oae oae-demo:latest /bin/bash # you'll be root
# if you need to run something as another user, try the `runuser` command like this: runuser -l node -c 'ls -la'
````

## License

[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Foaeproject%2Foae-demo.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Foaeproject%2Foae-demo?ref=badge_large)
