using Models.Post.Authentication;
using Repositories.Interfaces;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class UserService : IUserService
    {
        private readonly IUserRepository _userRepository;
        public UserService(IUserRepository userRepository)
        {
            _userRepository = userRepository;
        }
        public void CreateUser(Models.Post.Authentication.User user)
        {
            Models.User user_exists = _userRepository.GetByUsername(user.Username);
            if (user_exists != null)
            {
                throw new Exceptions.UserAlreadyExistsException(user.Username);
            }
            if (user.PhoneNumber.Length > 10)
            {
                throw new Exceptions.PhoneNumberTooLongException(user.PhoneNumber);
            }
            user.Email = user.Email.ToLower();
            _userRepository.Add(user);
        }

        public void UpdateUser(Models.User user)
        {
            _userRepository.Update(user);
        }

        public void UpdateUserLoginTime(Guid userId)
        {
            _userRepository.UpdateUserLoginTime(userId);
        }

        public async Task<Models.User> ValidateUserAsync(string username,string password)
        {
            Models.User validUser =await _userRepository.GetByUsernameAsync(username);
            if (validUser != null)
            {
                if (validUser.Password == password)
                {
                    return validUser;
                }
                else
                {
                    return null;
                }
            }
            else
            {
                return null;
            }
        }
    }
}
