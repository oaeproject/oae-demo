# How to get OAE running with docker

```bash
# Build the image
docker build --rm -t oae-demo:latest -f Dockerfile .
# Run the container (all servers)
docker run --rm -it -P --network host --name=oae oae-demo:latest
```

This is intended to work on linux alone.
