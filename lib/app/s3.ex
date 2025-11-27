defmodule App.S3 do
  @moduledoc "S3 API wrapper using Req + req_s3."

  @s3_opts aws_sigv4: [access_key_id: "minioadmin", secret_access_key: "minioadmin"],
           aws_endpoint_url_s3: "http://localhost:9000"

  @dev true

  def client() do
    Req.new()
    |> ReqS3.attach(@s3_opts)
  end

  def get(path) do
    client() |> Req.get!(url: path)
  end

  def create_bucket(bucket) do
    client()
    |> Req.put!(url: "s3://#{bucket}/?create")
  end

  def presign_url(bucket, key) do
    ReqS3.presign_url(
      [bucket: bucket, key: key, url: @s3_opts[:aws_endpoint_url_s3]] ++ @s3_opts[:aws_sigv4]
    )
  end

  @spec presign_form(bucket :: String.t(), key :: iodata()) :: %{
          fields: keyword(),
          url: String.t()
        }
  def presign_form(bucket, key) do
    options =
      [bucket: bucket, key: key, endpoint_url: @s3_opts[:aws_endpoint_url_s3]] ++
        @s3_opts[:aws_sigv4]

    if @dev do
      presign_form(options)
    else
      ReqS3.presign_form(options)
    end
  end

  # copied code, removed x-amz-server-side-encryption
  defp presign_form(options) when is_list(options) do
    # aws_credentials returns this key so let's ignore it
    options = Keyword.drop(options, [:credential_provider])

    Keyword.validate!(
      options,
      [
        :region,
        :access_key_id,
        :secret_access_key,
        :content_type,
        :max_size,
        :datetime,
        :expires_in,
        :bucket,
        :key,
        :endpoint_url
      ]
    )

    service = "s3"
    region = Keyword.get(options, :region, System.get_env("AWS_REGION", "us-east-1"))

    access_key_id =
      options[:access_key_id] || System.get_env("AWS_ACCESS_KEY_ID") ||
        raise ArgumentError,
              ":access_key_id option or AWS_ACCESS_KEY_ID system environment variable must be set"

    secret_access_key =
      options[:secret_access_key] || System.get_env("AWS_SECRET_ACCESS_KEY") ||
        raise ArgumentError,
              ":secret_access_key option or AWS_SECRET_ACCESS_KEY system environment variable must be set"

    bucket = Keyword.fetch!(options, :bucket)
    key = Keyword.fetch!(options, :key)
    content_type = Keyword.get(options, :content_type)
    max_size = Keyword.get(options, :max_size)
    datetime = Keyword.get(options, :datetime, DateTime.utc_now())
    expires_in = Keyword.get(options, :expires_in, 60 * 60 * 1000)

    datetime = DateTime.truncate(datetime, :second)
    datetime = DateTime.add(datetime, expires_in, :millisecond)
    datetime_string = datetime |> DateTime.truncate(:second) |> DateTime.to_iso8601(:basic)
    date_string = binary_part(datetime_string, 0, 8)

    credential = "#{access_key_id}/#{date_string}/#{region}/#{service}/aws4_request"

    amz_headers = [
      # Commented out here
      # {"x-amz-server-side-encryption", "AES256"},
      {"x-amz-credential", credential},
      {"x-amz-algorithm", "AWS4-HMAC-SHA256"},
      {"x-amz-date", datetime_string}
    ]

    content_type_conditions =
      if content_type do
        [["eq", "$Content-Type", "#{content_type}"]]
      else
        []
      end

    content_length_range_conditions =
      if max_size do
        [["content-length-range", 0, max_size]]
      else
        []
      end

    conditions =
      [
        %{"bucket" => "#{bucket}"},
        ["eq", "$key", "#{key}"]
      ] ++
        content_type_conditions ++
        content_length_range_conditions ++
        Enum.map(amz_headers, fn {key, value} -> %{key => value} end)

    policy = %{
      "expiration" => DateTime.to_iso8601(datetime),
      "conditions" => conditions
    }

    encoded_policy = policy |> Jason.encode!() |> Base.encode64()

    signature =
      Req.Utils.aws_sigv4(
        encoded_policy,
        date_string,
        region,
        service,
        secret_access_key
      )

    fields =
      Map.merge(
        Map.new(amz_headers),
        %{
          "key" => key,
          "policy" => encoded_policy,
          "x-amz-signature" => signature
        }
      )

    fields =
      if content_type do
        Map.merge(fields, %{"content-type" => content_type})
      else
        fields
      end

    endpoint_url = options[:endpoint_url] || System.get_env("AWS_ENDPOINT_URL_S3")

    url =
      if endpoint_url do
        "#{endpoint_url}/#{bucket}"
      else
        "https://#{options[:bucket]}.s3.amazonaws.com"
      end

    %{
      url: url,
      fields: Enum.to_list(fields)
    }
  end
end
