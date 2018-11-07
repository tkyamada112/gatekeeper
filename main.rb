require 'sinatra/base'
require 'ipaddr'
require 'resolv'
require 'aws-sdk'
require 'unindent'
require './config.rb'

class GateKeeper < Sinatra::Base
  def valid_ip?(ip_str)
    !!IPAddr.new(ip_str) rescue false
  end

  def create_client(env)
    case env
    when "develop"
      client = Aws::EC2::Client.new(
        access_key_id:     ENV['DEV_AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['DEV_AWS_SECRET_ACCESS_KEY'],
        region:            ENV['AWS_REGION']
      )
      sgid = DEV_SGID
    when "production"
      client = Aws::EC2::Client.new(
        access_key_id:     ENV['PRD_AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['PRD_AWS_SECRET_ACCESS_KEY'],
        region:            ENV['AWS_REGION']
      )
      sgid = PRD_SGID
    end
    return client, sgid
  end

  def create_message(door, env, ip, user)
    text = <<-"EOS".unindent
      #{env}: SSH port is #{door}ed from `#{ip}`.
      This operation executed by #{user}.
    EOS
    return text
  end

  post '/' do
    return status 403 unless params[:token] == SLACK_OUTGOING_TOKEN

    message = ""
    response_message = ""
    res_msg   = ""
    res_code  = ""

    message = params["text"].gsub(/gate/, "").strip
    door, env, ip, user = "", "", "", ""

    door = message.split(" ")[0] if %w(open close).include?(message.split(" ")[0]) != nil
    env  = message.split(" ")[1] if %w(develop production).include?(message.split(" ")[1]) != nil 
    ip   = message.split(" ")[2] if valid_ip?(message.split(" ")[2]) == true
    user = params["user_name"]

    response_message = {"text" => "Error.Please enter it in the following format. `gate open/close develop/production xxx.xxx.xxx.xxx` "} if %W(#{env} #{door} #{ip} #{user}).any?(&:empty?) || message.split(" ").size != 3
    response_message = {"text" => "Your operation is not Allow." } if !USERS.member?(params["user_name"])

    if response_message.empty?
      client, sgid = create_client(env)

      case door
      when "open"
        begin
          res_code = client.authorize_security_group_ingress(
                                                          {
                                                            group_id: "#{sgid}",
                                                            ip_permissions: [
                                                              {
                                                                from_port: 22,
                                                                to_port: 22,
                                                                ip_protocol: 'tcp',
                                                                ip_ranges: [
                                                                  {
                                                                    cidr_ip: "#{ip}/32",
                                                                  }
                                                                ]
                                                              }
                                                            ]
                                                          }
                                                        )
        rescue => error
          err_msg = ""
          err_msg = error.message
        end
      when "close"
        begin
          client.revoke_security_group_ingress(
                                             {
                                               group_id: "#{sgid}",
                                                 ip_permissions: [
                                                   {
                                                     from_port: 22,
                                                     to_port: 22,
                                                     ip_protocol: 'tcp',
                                                     ip_ranges: [
                                                       {
                                                         cidr_ip: "#{ip}/32",
                                                       }
                                                     ]
                                                   }
                                                 ]
                                               }
                                             )
        rescue => error
          err_msg = ""
          err_msg = error.message
        end
      end

      if err_msg.nil?
        response_message = { "text" => create_message(env, door, ip, user) }
      else
        response_message = { "text" => err_msg }
      end

    end
    response_message.to_json
  end
end
