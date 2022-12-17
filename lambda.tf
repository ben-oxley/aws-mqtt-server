variable "url" {
  description = "Influx url" //https://eu-central-1-1.aws.cloud2.influxdata.com
  type        = string
  default = "https://eu-central-1-1.aws.cloud2.influxdata.com"
}
variable "token" {
  description = "influx token"
  type        = string
  sensitive = true
}
variable "org" {
  description = "influx org"
  type        = string
}
variable "bucket" {
  description = "influx bucket"
  default = "sensors"
  type        = string
}

resource "aws_lambda_function" "publish_to_influx" {
  filename         = "${data.archive_file.lambda_zip_inline.output_path}"
  source_code_hash = "${data.archive_file.lambda_zip_inline.output_base64sha256}"
  role = aws_iam_role.iam_for_lambda.arn
  function_name = "publish_to_influx"
  handler = "main.handler"
  runtime = "nodejs16.x"
  environment {
    variables = {
      url = var.url
      token=var.token
      org=var.org
      bucket=var.bucket
    }
  }
  layers = [aws_lambda_layer_version.influxlayer.arn]
}

resource "aws_lambda_layer_version" "influxlayer" {
  filename = "${data.archive_file.influxlayerdata.output_path}"
  source_code_hash = "${data.archive_file.influxlayerdata.output_base64sha256}"
  layer_name = "influx"
}

data "archive_file" "influxlayerdata" {
  type = "zip"
  output_path = "/tmp/lambda_influx_layer.zip"
  source_dir = "./influxlayer"
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
    
    console.log(event)

    console.log("url: "+url+" org: "+org+" bucket: "+bucket)

  
    //create InfluxDB api client with URL and token, then create Write API for the specific org and bucket
    const writeApi = await new InfluxDB({url, token}).getWriteApi(org, bucket);

    //create a data point with health as the measurement name, a field value for heart beat, and userID tag
    const dataPoint0 = new Point('power')
        .tag('ip', event['ip'])
        .tag('type', 'total')
        .tag('send_time',event['time'])
        .tag('mac', event['mac'])
        .floatField('value', event['value0'])
    
    const dataPoint1 = new Point('power')
        .tag('ip', event['ip'])
        .tag('type', 'top')
        .tag('send_time',event['time'])
        .tag('mac', event['mac'])
        .floatField('value', event['value1'])
      
    const dataPoint2 = new Point('power')
        .tag('ip', event['ip'])
        .tag('type', 'bottom')
        .tag('send_time',event['time'])
        .tag('mac', event['mac'])
        .floatField('value', event['value2'])
    
    const dataPoint3 = new Point('power')
        .tag('ip', event['ip'])
        .tag('type', 'garage')
        .tag('send_time',event['time'])
        .tag('mac', event['mac'])
        .floatField('value', event['value3'])

    const devicePoint = new Point('device')
        .tag('ip', event['ip'])
        .tag('rssi', event['rssi'])
        .tag('mac', event['mac'])
        .tag('type', 'garage')
        .intField('rssi', event['rssi'])

    //write data point
    await writeApi.writePoint(devicePoint)
    await writeApi.writePoint(dataPoint0)
    await writeApi.writePoint(dataPoint1)
    await writeApi.writePoint(dataPoint2)
    await writeApi.writePoint(dataPoint3)

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

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_permission" "allow_invoke_from_iot_core" {
  statement_id  = "AllowInvokeFromIotCore"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.publish_to_influx.function_name
  principal     = "iot.amazonaws.com"
}

resource "aws_cloudwatch_log_group" "function_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.publish_to_influx.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_iam_policy" "function_logging_policy" {
  name   = "function-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "function_logging_policy_attachment" {
  role = aws_iam_role.iam_for_lambda.id
  policy_arn = aws_iam_policy.function_logging_policy.arn
}