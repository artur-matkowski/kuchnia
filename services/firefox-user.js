// Load-bearing: the harvest reads cookies.sqlite after a clean shutdown, and either of these
// two set the other way empties it exactly then.
user_pref("privacy.sanitize.sanitizeOnShutdown", false);
user_pref("privacy.clearOnShutdown.cookies", false);
user_pref("browser.privatebrowsing.autostart", false);

// Everything below is only about not putting a dialog between a person and the sign-in form.
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage", "https://myaccount.google.com/");
user_pref("browser.startup.firstrunSkipsHomepage", false);
user_pref("browser.laterrun.enabled", false);
user_pref("browser.rights.3.shown", true);
user_pref("browser.uitour.enabled", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("trailhead.firstrun.didSeeAboutWelcome", true);
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("app.update.auto", false);
