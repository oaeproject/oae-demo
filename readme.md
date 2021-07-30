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

There's only so much debugging you can do being `node`, which is the last set user in the Dockerfile. If you need to debug the image, remove that line and build it locally, you'll be root and have all the access you need.