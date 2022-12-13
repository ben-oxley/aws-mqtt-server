# aws-mqtt-server

There is an IoT Device Simulator project that can be deployed as a cloudformation stack from here:
https://s3.amazonaws.com/solutions-reference/iot-device-simulator/latest/iot-device-simulator.template 
with documentation here: https://docs.aws.amazon.com/solutions/latest/iot-device-simulator/deployment.html

Grafana setup guide: https://aws.amazon.com/blogs/iot/influxdb-and-grafana-with-aws-iot-to-visualize-time-series-data/

When applying, use the format: 

terraform apply -var token="[token]" -var org="[org (usually email for influx cloud)]"