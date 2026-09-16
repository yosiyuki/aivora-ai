# Public, generated pages (issue #6). Drawn for every HTTP role, so the public
# process serves exactly these and nothing else.
#
# Pages are looked up by the URL that was issued to them (ContentItem#url),
# never rebuilt from params: URLs are immutable (Technical Architecture §23),
# so the stored string is the only thing allowed to resolve a page.
root "public/pages#show"

# Catch-all last: `up` and the admin routes are drawn before this file's
# root, and `format: false` keeps a dot in the path (a slug like "a.b") from
# being parsed as an extension and losing part of the stored URL.
get "*path" => "public/pages#show", as: :public_page, format: false
