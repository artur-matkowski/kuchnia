#include "KeyBindings.hpp"

#include <QKeySequence>
#include <QSettings>

#include "integrations/Log.hpp"

namespace {

// The whole action set, in the order the settings screen walks it - which is the order that
// screen draws its rows in, and nothing checks that either. That walk is column-major and the
// two columns hold a different number of cards, so this table is the left column's three cards
// top to bottom and then the right column's two: see docs/settings.md. An id is written here
// and again in the QML that draws its row: a misspelt one is a row with no label that can never
// be bound.
//
// The six panel actions ship unbound on purpose: a key that opens a gate is not something to
// guess at on someone's behalf. Everything else is bound, because none of it commands any
// hardware and each of them undoes itself.
struct Definition {
	const char* id;
	const char* label;
	int         key;
};

const Definition kActions[] = {
	{"context-previous", "poprzedni widok",   Qt::Key_Left},
	{"context-next",     "następny widok",    Qt::Key_Right},
	{"menu",             "menu",              Qt::Key_Space},
	{"confirm",          "zatwierdź",         Qt::Key_Return},
	{"refresh",          "odśwież",           Qt::Key_F5},

	// The map's five. PageUp/PageDown and not Plus/Minus, which is what a reader reaches for:
	// the main row's unshifted key arrives as Key_Equal and only its shifted form as Key_Plus,
	// so a Key_Plus binding answers the keypad and Shift rather than the key with + printed on
	// it. Up and Down are free everywhere but the settings screen, which hardwires them - and
	// none of these five does anything off the map context anyway.
	{"map-people",       "lista osób",        Qt::Key_F2},
	{"map-previous",     "poprzednia osoba",  Qt::Key_Up},
	{"map-next",         "następna osoba",    Qt::Key_Down},
	{"map-zoom-in",      "przybliż",          Qt::Key_PageUp},
	{"map-zoom-out",     "oddal",             Qt::Key_PageDown},

	{"gate-open",        "otwórz",            0},
	{"gate-stop",        "stop",              0},
	{"gate-close",       "zamknij",           0},

	{"radio-play-stop",  "graj / stop",       0},
	{"radio-next",       "następna stacja",   0},
	{"radio-previous",   "poprzednia stacja", 0},
	{"volume-up",        "głośniej",          Qt::Key_VolumeUp},
	{"volume-down",      "ciszej",            Qt::Key_VolumeDown},

	{"camera-1",         "kamera 1",          Qt::Key_1},
	{"camera-2",         "kamera 2",          Qt::Key_2},
	{"camera-3",         "kamera 3",          Qt::Key_3},
	{"camera-4",         "kamera 4",          Qt::Key_4},
	{"camera-5",         "kamera 5",          Qt::Key_5},
	{"camera-grid",      "powrót do siatki",  Qt::Key_0},
};

const char* const kGroup = "keys/";

QString keyText(int key)
{
	if (key == 0)
		return QString();
	return QKeySequence(QKeyCombination(static_cast<Qt::Key>(key)))
		.toString(QKeySequence::PortableText);
}

// The file is meant to be edited by hand as well as by the screen, so a value that is not a
// key name is a typo somebody made and wants to hear about rather than a reason to refuse to
// start. It reads back as unbound.
int keyFrom(const QString& text, const QString& id)
{
	if (text.isEmpty())
		return 0;

	const QKeySequence sequence = QKeySequence::fromString(text, QKeySequence::PortableText);
	if (sequence.count() != 1 || sequence[0].key() == Qt::Key_unknown) {
		LOG_WARN(applog::App) << "key binding '" << text.toStdString() << "' for "
		                      << id.toStdString()
		                      << " is not a key name - the action is left unbound";
		return 0;
	}
	return static_cast<int>(sequence[0].key());
}

}  // namespace

KeyBindings::KeyBindings(const QString& path, bool reset, QObject* parent)
	: QObject(parent)
	, m_path(path)
{
	for (const Definition& action : kActions) {
		m_ids.append(QString::fromLatin1(action.id));
		m_keys.append(action.key);
	}

	if (reset) {
		open()->clear();
		save();
		LOG_INFO(applog::App) << "key bindings reset to the defaults";
		return;
	}

	load();
}

std::unique_ptr<QSettings> KeyBindings::open() const
{
	// These two names are QSettings' own path arithmetic and the only ones there are: nothing
	// sets an application-wide organisation or application name, so a QSettings constructed
	// without them opens no file and says so only as a warning.
	return m_path.isEmpty()
		? std::make_unique<QSettings>(QSettings::IniFormat, QSettings::UserScope,
		                              QStringLiteral("kuchnia"), QStringLiteral("keys"))
		: std::make_unique<QSettings>(m_path, QSettings::IniFormat);
}

// A missing entry is an action that has never been touched and takes its default; an entry
// that is present and empty is somebody having pressed Escape on that row. The two must not
// be conflated, or an unbound action comes back bound on the next start.
void KeyBindings::load()
{
	const std::unique_ptr<QSettings> file = open();
	LOG_INFO(applog::App) << "key bindings: " << file->fileName().toStdString();

	// Nothing stored yet: write the defaults out, so the file is there to be read and edited
	// by hand rather than appearing only once somebody has used the screen.
	if (file->allKeys().isEmpty()) {
		save();
		emit bindingsChanged();
		return;
	}

	for (int i = 0; i < m_ids.size(); ++i) {
		const QString entry = QString::fromLatin1(kGroup) + m_ids.at(i);
		if (!file->contains(entry))
			continue;
		m_keys[i] = keyFrom(file->value(entry).toString(), m_ids.at(i));
	}

	emit bindingsChanged();
}

void KeyBindings::save()
{
	const std::unique_ptr<QSettings> file = open();

	for (int i = 0; i < m_ids.size(); ++i)
		file->setValue(QString::fromLatin1(kGroup) + m_ids.at(i), keyText(m_keys.at(i)));

	// Without this the screen accepts a binding, draws it, and forgets it on the next start -
	// a home directory that cannot be written says nothing on its own.
	file->sync();
	if (file->status() != QSettings::NoError)
		LOG_ERROR(applog::App) << "key bindings could not be written to "
		                       << file->fileName().toStdString()
		                       << " - they will not survive a restart";
}

QStringList KeyBindings::actions() const
{
	return m_ids;
}

QVariantMap KeyBindings::labels() const
{
	QVariantMap out;
	// fromUtf8 on the label and fromLatin1 on the id: the labels carry Polish and this file is
	// UTF-8, and a Latin-1 decode of one is mojibake on the settings screen with no error
	// anywhere - see docs/input.md. The ids are ASCII keys and stay Latin-1.
	for (const Definition& action : kActions)
		out.insert(QString::fromLatin1(action.id), QString::fromUtf8(action.label));
	return out;
}

QVariantMap KeyBindings::keys() const
{
	QVariantMap out;
	for (int i = 0; i < m_ids.size(); ++i)
		out.insert(m_ids.at(i), keyText(m_keys.at(i)));
	return out;
}

QString KeyBindings::actionFor(int key) const
{
	if (key == 0)
		return QString();
	const int i = m_keys.indexOf(key);
	return i < 0 ? QString() : m_ids.at(i);
}

void KeyBindings::capture(const QString& action)
{
	if (!m_ids.contains(action)) {
		LOG_WARN(applog::App) << "no such action: " << action.toStdString();
		return;
	}

	setRefused(QString());
	m_capturing = action;
	emit capturingChanged();
}

void KeyBindings::cancel()
{
	setRefused(QString());
	if (m_capturing.isEmpty())
		return;
	m_capturing.clear();
	emit capturingChanged();
}

void KeyBindings::apply(int key)
{
	const int row = m_ids.indexOf(m_capturing);
	if (row < 0)
		return;

	// Escape is the only way to give a key back, so it is the one key no action can hold.
	if (key == Qt::Key_Escape) {
		m_keys[row] = 0;
		save();
		emit bindingsChanged();
		cancel();
		return;
	}

	// A key the platform has no name for arrives as this one value whatever button produced it,
	// so binding it would bind every unnamed button on the device at once - and it has no text
	// to write to the file either, which reads back as unbound on the next start. Remotes reach
	// this constantly: a consumer-control node emits far more usages than a keymap names.
	if (key == Qt::Key_unknown) {
		LOG_WARN(applog::App) << "a key with no name on this system cannot be bound";
		setRefused(QStringLiteral("klawisz bez nazwy"));
		return;
	}

	// The key that arms a row is the key that abandons it, which is why binding an action to
	// whatever `confirm` holds cannot be done from here - the conflict below would refuse it
	// anyway.
	const QString holder = actionFor(key);
	if (holder == QStringLiteral("confirm")) {
		cancel();
		return;
	}

	if (!holder.isEmpty() && holder != m_capturing) {
		// Still armed: the next key can simply be tried without arming the row again.
		setRefused(QStringLiteral("zajęty przez ") + labels().value(holder).toString());
		return;
	}

	m_keys[row] = key;
	save();
	emit bindingsChanged();
	cancel();
}

void KeyBindings::setRefused(const QString& message)
{
	if (message == m_refused)
		return;
	m_refused = message;
	emit refusedChanged();
}
