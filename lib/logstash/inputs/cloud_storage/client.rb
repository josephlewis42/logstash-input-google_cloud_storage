# encoding: utf-8

# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'thread'
require 'java'
require 'logstash-input-google_cloud_storage_jars.rb'
require 'logstash/inputs/cloud_storage/blob_adapter'

module LogStash
  module Inputs
    module CloudStorage
      # Client provides all the required transport and authentication setup for the plugin.
      class Client
        def initialize(bucket, json_key_path, logger)
          @logger = logger
          @bucket = bucket

          # create client
          @storage = initialize_storage json_key_path
        end

        def list_blobs
          @storage.list(@bucket).iterateAll().each do |blobname|
            yield LogStash::Inputs::CloudStorage::BlobAdapter.new(blobname)
          end
        rescue Java::ComGoogleCloudStorage::StorageException => e
          raise "Error listing bucket contents: #{e}"
        end

        private

        def initialize_storage(json_key_path)
          com.google.cloud.storage.StorageOptions.newBuilder()
             .setCredentials(credentials(json_key_path))
             .setHeaderProvider(http_headers)
             .setRetrySettings(retry_settings)
             .build()
             .getService()
        end

        java_import 'com.google.auth.oauth2.GoogleCredentials'
        def credentials(json_key_path)
          return GoogleCredentials.getApplicationDefault() if json_key_path.empty?

          key_file = java.io.FileInputStream.new(json_key_path)
          GoogleCredentials.fromStream(key_file)
        end

        java_import 'com.google.api.gax.rpc.FixedHeaderProvider'
        def http_headers
          gem_name = 'logstash-input-google_cloud_storage'
          gem_version = '1.0.0'
          user_agent = "Elastic/#{gem_name} version/#{gem_version}"

          FixedHeaderProvider.create({ 'User-Agent' => user_agent })
        end

        java_import 'com.google.api.gax.retrying.RetrySettings'
        java_import 'org.threeten.bp.Duration'
        def retry_settings
          # backoff values taken from com.google.api.client.util.ExponentialBackOff
          RetrySettings.newBuilder()
                       .setInitialRetryDelay(Duration.ofMillis(500))
                       .setRetryDelayMultiplier(1.5)
                       .setMaxRetryDelay(Duration.ofSeconds(60))
                       .setInitialRpcTimeout(Duration.ofSeconds(20))
                       .setRpcTimeoutMultiplier(1.5)
                       .setMaxRpcTimeout(Duration.ofSeconds(20))
                       .setTotalTimeout(Duration.ofMinutes(15))
                       .build()
        end
      end
    end
  end
end
