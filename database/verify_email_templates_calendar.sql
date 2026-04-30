SELECT slug,
  LENGTH(body_html) AS html_length,
  updated_at
FROM email_templates
WHERE slug IN ('approval', 'approval-plus-one')
ORDER BY slug;

SELECT slug,
  body_html LIKE '%calendar_google_url%' AS has_google_link,
  body_html LIKE '%calendar_ics_url%' AS has_ics_link
FROM email_templates
WHERE slug IN ('approval', 'approval-plus-one')
ORDER BY slug;
