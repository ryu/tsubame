# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.font_src    :self, :data
    # Entry content can embed images from arbitrary feed hosts.
    policy.img_src     :self, :data, :https
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    # Stimulus fetches Hatena bookmark counts from the Hatena API.
    policy.connect_src :self, "https://bookmark.hatenaapis.com"
    policy.form_action :self
    policy.frame_ancestors :self
  end

  # Generate session nonces for permitted importmap and inline scripts/styles.
  # Turbo picks this nonce up from csp_meta_tag for its runtime progress-bar <style>,
  # and importmap-rails applies it to the import map / module preload scripts.
  #
  # The nonce lives in the session rather than being derived from session.id: the id
  # is nil until a session cookie exists, and an empty nonce renders the whole
  # source list invalid, so every inline script -- the import map included -- is
  # blocked and Stimulus never starts. The login cookie is permanent while the
  # session cookie is not, so a returning browser hits exactly that request and the
  # keyboard shortcuts stay dead until a reload.
  config.content_security_policy_nonce_generator = ->(request) { request.session[:csp_nonce] ||= SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[ script-src style-src ]
end
