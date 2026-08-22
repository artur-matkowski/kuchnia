#pragma once

#include <memory>

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

class QSettings;

// Every action the panel can be told to do, and the key that does it.
//
// The bindings are one INI file of their own, read and written here and nowhere else. It is
// not the config Settings.cpp resolves: that one also reads the environment and argv and is
// read-only after startup, and this one is written by the settings screen while the scene is
// running.
//
// A keycode is the whole of a binding - modifiers are not part of it, and the keypad's Enter
// is a different keycode from the main one. See docs/input.md.
class KeyBindings : public QObject {
	Q_OBJECT

	// The ids, in the order the settings screen walks them. A card that draws its rows in a
	// different order is a selection that jumps about; nothing checks that.
	Q_PROPERTY(QStringList actions READ actions CONSTANT)
	Q_PROPERTY(QVariantMap labels READ labels CONSTANT)

	// id -> the key's portable name, empty when the action is unbound. A map rather than an
	// invokable, so a row in QML is a binding that re-evaluates when something is rebound.
	Q_PROPERTY(QVariantMap keys READ keys NOTIFY bindingsChanged)

	// The row waiting for a key, empty when nothing is. While this is set every key press
	// belongs to it - Main.qml routes nothing else anywhere.
	Q_PROPERTY(QString capturing READ capturing NOTIFY capturingChanged)

	// The label of the action already holding the key that was just refused, for the armed
	// row to show. Cleared by the next capture, bind or cancel.
	Q_PROPERTY(QString refused READ refused NOTIFY refusedChanged)

public:
	// An empty path is the standard per-user config location. `reset` erases whatever is
	// stored and writes the defaults back, which is the only way back from a map that has
	// bound the screen out of reach.
	explicit KeyBindings(const QString& path, bool reset, QObject* parent = nullptr);

	QStringList actions() const;
	QVariantMap labels() const;
	QVariantMap keys() const;
	QString     capturing() const { return m_capturing; }
	QString     refused() const { return m_refused; }

	// The reverse lookup every key press goes through. Empty for a key nothing holds.
	Q_INVOKABLE QString actionFor(int key) const;

	Q_INVOKABLE void capture(const QString& action);
	Q_INVOKABLE void cancel();

	// The armed row's answer to a key press: Escape unbinds it, the key bound to `confirm`
	// cancels, a key another action holds is refused and the row stays armed, and anything
	// else binds and saves.
	Q_INVOKABLE void apply(int key);

signals:
	void bindingsChanged();
	void capturingChanged();
	void refusedChanged();

private:
	std::unique_ptr<QSettings> open() const;
	void                       load();
	void                       save();
	void                       setRefused(const QString& label);

	QString     m_path;
	QStringList m_ids;
	// Parallel to m_ids: the keycode each action is bound to, 0 for unbound.
	QList<int>  m_keys;
	QString     m_capturing;
	QString     m_refused;
};
