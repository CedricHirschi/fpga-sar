# Check if venv folder exists. If not, create venv using python
# If venv exists, activate it
# If venv is already activated, do nothing

# Check if venv folder exists
if [ ! -d "venv" ]; then
    # Create venv using python
    echo "Creating venv folder"
    python3 -m venv venv
fi

# Activate venv (in venv/Scripts if on windows, venv/bin if on linux)
if [ -d "venv/Scripts" ]; then
    echo "Activating venv"
    source venv/Scripts/activate
elif [ -d "venv/bin" ]; then
    echo "Activating venv"
    source venv/bin/activate
fi

# Install apio if not installed or second argument is passed
if [ ! -d "apio" ] || [ "$2" == "install" ];
then
    echo "Installing requirements"
    pip install -r requirements.txt -q --require-virtualenv --no-input
fi