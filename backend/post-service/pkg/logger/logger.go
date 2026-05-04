package logger

import (
	"os"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var L *zap.Logger

func Init(service string) {
	enc := zapcore.EncoderConfig{
		TimeKey: "ts", LevelKey: "level", NameKey: "logger",
		CallerKey: "caller", MessageKey: "msg",
		EncodeLevel: zapcore.LowercaseLevelEncoder,
		EncodeTime:  zapcore.ISO8601TimeEncoder,
		EncodeCaller: zapcore.ShortCallerEncoder,
	}
	var core zapcore.Core
	if os.Getenv("APP_ENV") == "production" {
		core = zapcore.NewCore(zapcore.NewJSONEncoder(enc),
			zapcore.AddSync(os.Stdout), zapcore.InfoLevel)
	} else {
		enc.EncodeLevel = zapcore.CapitalColorLevelEncoder
		core = zapcore.NewCore(zapcore.NewConsoleEncoder(enc),
			zapcore.AddSync(os.Stdout), zapcore.DebugLevel)
	}
	L = zap.New(core, zap.AddCaller()).With(zap.String("service", service))
}
func Info(m string, f ...zap.Field)  { L.Info(m, f...) }
func Warn(m string, f ...zap.Field)  { L.Warn(m, f...) }
func Error(m string, f ...zap.Field) { L.Error(m, f...) }
func Fatal(m string, f ...zap.Field) { L.Fatal(m, f...) }
func Sync() { _ = L.Sync() }
