<p align="center">
    <img alt="piston_sdk logo" src="img/logo.svg" width=125 />
</p>

<h1 align="center">
    Piston Ruby SDK
</h1>

<p align="center">
    <strong><i>piston_sdk</i></strong> is a lightweight Ruby gem executing code using the <a href="https://github.com/engineer-man/piston"><i>Piston API</i></a>.
</p>

<div align="center">

[![Gem Version](https://badge.fury.io/rb/piston_sdk.svg)](https://badge.fury.io/rb/piston_sdk) [![GitHub Actions](https://img.shields.io/github/actions/workflow/status/alvii147/piston-ruby-sdk/main.yml?branch=main&label=GitHub%20Actions&logo=github)](https://github.com/alvii147/piston-ruby-sdk/actions) [![License](https://img.shields.io/github/license/alvii147/piston-ruby-sdk)](https://github.com/alvii147/piston-ruby-sdk/blob/main/LICENSE)

</div>

## Installation

```bash
gem install piston_sdk
```

## Usage

```ruby
require 'piston_sdk'

client = PistonSDK::Client.new
client.add_file(content: "puts 42", name: "app.rb")
results = client.execute(language: "ruby", version: "3.0.1")

puts results.run.stdout # 42
```

## Acknowledgements

* [Piston API](https://github.com/engineer-man/piston)
