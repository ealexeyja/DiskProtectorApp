#!/bin/bash

echo "=== Corrigiendo nullability en RelayCommand ==="

# Actualizar RelayCommand para manejar correctamente nullability
cat > src/DiskProtectorApp/RelayCommand.cs << 'RELAYCOMMANDEOF'
using System;
using System.Threading.Tasks;
using System.Windows.Input;

namespace DiskProtectorApp
{
    public class RelayCommand : ICommand
    {
        private readonly Action<object?>? _execute;
        private readonly Func<object?, Task>? _executeAsync;
        private readonly Predicate<object?>? _canExecute;

        public RelayCommand(Action<object?> execute, Predicate<object?>? canExecute = null)
        {
            _execute = execute ?? throw new ArgumentNullException(nameof(execute));
            _canExecute = canExecute;
        }

        public RelayCommand(Func<object?, Task> executeAsync, Predicate<object?>? canExecute = null)
        {
            _executeAsync = executeAsync ?? throw new ArgumentNullException(nameof(executeAsync));
            _canExecute = canExecute;
        }

        public bool CanExecute(object? parameter)
        {
            bool result = _canExecute?.Invoke(parameter) ?? true;
            return result;
        }

        public async void Execute(object? parameter)
        {
            if (_executeAsync != null)
            {
                await _executeAsync(parameter);
            }
            else if (_execute != null)
            {
                _execute(parameter);
            }
        }

        public event EventHandler? CanExecuteChanged
        {
            add 
            { 
                CommandManager.RequerySuggested += value; 
            }
            remove 
            { 
                CommandManager.RequerySuggested -= value; 
            }
        }

        public void RaiseCanExecuteChanged()
        {
            CommandManager.InvalidateRequerySuggested();
        }
    }
}
RELAYCOMMANDEOF

echo "✅ RelayCommand corregido para manejar nullability correctamente"
echo "   Cambios principales:"
echo "   - Campos _execute y _executeAsync ahora son nullable (?)"  
echo "   - Verificación de null antes de ejecutar"
echo "   - Constructor actualizado para manejar ambos tipos de comandos"
echo ""
echo "Para aplicar los cambios:"
echo "1. git add src/DiskProtectorApp/RelayCommand.cs"
echo "2. git commit -m \"fix: Corregir nullability en RelayCommand\""
echo "3. git push origin main"
