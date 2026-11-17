# RxLab

A prescription entry and labeling tool for pharmacy skills and compounding labs, in **one HTML file**.
No installation, no administrator rights, no plug-ins: open `RxLab.html` in Chrome or Edge.

**Try it:** https://acastleman.github.io/RxLab/RxLab.html (standalone demo; nothing you type leaves your browser)

## What students do

1. Sign in with an email and enter a prescription: patient, prescriber, dates, compounded product, sig, quantity, refills.
2. Picklists fill prescriber details (credential, address, phone, NPI) and product details (strength, dosage form, formula).
   Look-alike entries mean students must still match the prescription.
3. A sig code (`APP AAA BID PRN ITCH`) is written out into Directions, which is what prints, so students read and edit it.
4. A live **Label check** lists 14 required label elements and turns each red until it is present.
5. Print the label and up to five auxiliary labels on your label stock. Every label says **FOR EDUCATIONAL USE ONLY**.

Deliberate choices: there is no beyond-use-date calculator (students enter the discard-after date), and the lot number
is generated and locked.

## Two ways to run it

**Standalone (default).** Leave `supabaseUrl` and `supabaseKey` blank in `RXLAB_CONFIG`. Prescriptions save in that
browser only, and the History tab can export a CSV. Entering and printing work with no internet connection.

**With a course database.** Students can enter on their own laptop and print on a lab PC with a pickup code, and every
save reaches the instructor for grading. This needs an internet connection when saving and loading; a save that cannot
be sent waits on the device and retries.

1. Create a free [Supabase](https://supabase.com) project and run `supabase_rxlab.sql` in its SQL Editor.
   Edit the two `EMAIL CHECK` lines to your school's domain.
2. In `RxLab.html`, set `RXLAB_CONFIG.supabaseUrl` and `supabaseKey` to the project URL and **publishable** key, and
   `emailPattern` to the same domain rule. Never put the secret (service_role) key in the HTML.
3. Hand out that copy (LMS download, shared drive, or the lab PCs' desktops).
4. Grade with `grade_rxlab.R` (needs the secret key, kept in your `.Renviron`). Edit `CASE_KEY` for your cases.

Students' emails and entries are stored in **your** Supabase project; treat them as education records under your
institution's FERPA policy.

## Adapting it

All of this is in the `<script>` near the top of `RxLab.html`:

| What | Where |
|---|---|
| Prescribers | `PRESCRIBERS` (the ones included are fictional) |
| Compounds and formulas | `PRODUCTS` (`id` is what the grader keys on) |
| Pharmacy name, address, phone | `RXLAB_CONFIG.pharmacy` (each PC can also change them in Setup) |
| Who may sign in | `RXLAB_CONFIG.emailPattern`, `emailHint`, `emailPlaceholder` |
| Auxiliary labels | `AUX` |
| Sig abbreviations | `SIG`, `UNITS`, `VERBS`, `INDICATIONS` |

**Label stock:** in Setup, choose "Lab label sheet" and enter the label's width and height and its offset from the
sheet's edges, then print the alignment test sheet and adjust. Labels under 2 in tall switch to a compact layout.

## Versions

- 1.5 (2026-11): sig expansion keeps plain English as typed ("as needed" no longer becomes "into the left ear").
- 1.4 (2026-10): compact layout for small label stock; the label check flags directions that do not fit.
- 1.2 (2026-10): pickup codes for entering on one device and printing on another.

Piloted in a non-sterile compounding lab, fall 2026.

## License

[MIT](LICENSE). Use it, change it, and share it, including in your own courses; keep the copyright notice.
The notice is also in the comment at the top of `RxLab.html`, so it travels with the single file.
RxLab is a teaching tool, not pharmacy software for dispensing to patients.

## Contact

Andrew Castleman, PharmD, MS, Union University College of Pharmacy: acastleman@uu.edu
