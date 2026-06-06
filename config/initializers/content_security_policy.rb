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
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[ script-src style-src ]

  # Report violations without enforcing the policy. Flip to enforcing only after
  # verifying in a browser that Turbo/Stimulus and styles work (Turbo injects a
  # runtime <style> for its progress bar, which needs nonce/handling under
  # enforced style-src).
  config.content_security_policy_report_only = true
end
