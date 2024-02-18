cat <<'MSG'

 _   __           _           _ _      _            
| | / /          (_)         | (_)    | |           
| |/ /  __ _ _ __ _  __ _  __| |_   __| | _____   __
|    \ / _` | '__| |/ _` |/ _` | | / _` |/ _ \ \ / /
| |\  \ (_| | |  | | (_| | (_| | || (_| |  __/\ V / 
\_| \_/\__,_|_|  |_|\__,_|\__,_|_(_)__,_|\___| \_/  
                                                    
                                                    
Forked From : https://github.com/yiisoft/yii2-docker

MSG

echo "PHP version: ${PHP_VERSION}"

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  fi
fi
