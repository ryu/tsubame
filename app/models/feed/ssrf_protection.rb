require "resolv"
require "ipaddr"

class Feed::SsrfError < StandardError; end

module Feed::SsrfProtection
  extend ActiveSupport::Concern

  BLOCKED_IP_RANGES = [
    IPAddr.new("0.0.0.0/8"),
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("::1/128"),
    IPAddr.new("fc00::/7"),
    IPAddr.new("fe80::/10")
  ].freeze

  class_methods do
    def blocked_ip_address?(ip_addr)
      BLOCKED_IP_RANGES.any? { |range| range.include?(ip_addr) }
    end

    def private_ip?(host)
      ip = Resolv.getaddress(host)
      ip_addr = IPAddr.new(ip)
      blocked_ip_address?(ip_addr)
    rescue Resolv::ResolvError, SocketError, IPAddr::InvalidAddressError
      true
    end
  end

  private

  def validate_url_safety!(uri)
    raise Feed::SsrfError, "URL must use HTTP or HTTPS" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    ip = Resolv.getaddress(uri.host)
    ip_addr = IPAddr.new(ip)
    raise Feed::SsrfError, "URL points to private network" if Feed.blocked_ip_address?(ip_addr)

    ip
  rescue Resolv::ResolvError, SocketError, IPAddr::InvalidAddressError
    raise Feed::SsrfError, "Cannot resolve hostname"
  end
end
