resource "aws_lambda_function" "publish_to_influx" {
  filename         = "${data.archive_file.lambda_zip_inline.output_path}"
  source_code_hash = "${data.archive_file.lambda_zip_inline.output_base64sha256}"
}

data "archive_file" "lambda_zip_inline" {
  type        = "zip"
  output_path = "/tmp/lambda_zip_inline.zip"
  source {
    content  = <<EOF

//import InfluxDB client, this is possible thanks to the layer we created
const {InfluxDB, Point, } = require('@influxdata/influxdb-client')

//grab environment variables
const org = process.env.org
const bucket = process.env.bucket
const token = process.env.token;
const url = process.env.url

//lambda event handler, this code is ran on every external request
exports.handler =  async (event) => {
    //parse the expected JSON from the body of the POST request
    var body = JSON.parse(event.body)

    //create InfluxDB api client with URL and token, then create Write API for the specific org and bucket
    const writeApi = await new InfluxDB({url, token}).getWriteApi(org, bucket);

    //create a data point with health as the measurement name, a field value for heart beat, and userID tag
    const dataPoint = new Point('health')
        .tag('userID', body['userID'])
        .floatField('heartRate', body['heartbeatRate'])

    //write data point
    await writeApi.writePoint(dataPoint)

    //close write API
    await writeApi.close().then(() => {
        console.log('WRITE FINISHED')
    })

    //send back response to the client
    const response = {
        statusCode: 200,
        body: JSON.stringify('Write successful'),
    };
    return response;
};
EOF
    filename = "main.js"
  }
}
