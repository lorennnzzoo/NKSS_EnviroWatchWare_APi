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
        private readonly ICryptoService cryptoService;
        private readonly IRoleService roleService;
        public UserService(IUserRepository userRepository, ICryptoService _cryptoService, IRoleService _roleService)
        {
            _userRepository = userRepository;
            cryptoService = _cryptoService;
            roleService = _roleService;
        }

        public void ActivateUser(Guid id)
        {
            _userRepository.Activate(id);
        }

        public void CreateAdminAccount()
        {
            var users = _userRepository.GetAll();
            //if (users.Any() || users == null)
            //{
                var adminRole=roleService.GetAllRoles().Where(e => e.Name.ToUpper() == "ADMIN").FirstOrDefault();
                var adminAccounts = users.Where(e => e.RoleId == adminRole.Id).FirstOrDefault();
                if (adminAccounts == null)
                {
                    Models.Post.Authentication.User user = new Models.Post.Authentication.User
                    {
                        Username = "Admin",
                        Password = "Admin@nksquare",
                        PhoneNumber = "0000000000",
                        Email = "admin@nksquare.com",
                        RoleId = adminRole.Id
                    };
                    CreateUser(user);
                }
                else
                {
                    //admin account already exists
                }
            //}
        }

        public void CreateUser(Models.Post.Authentication.User user)
        {
            if (roleService.GetAllRoles().Where(e => e.Id == user.RoleId).Select(e => e.Name).FirstOrDefault().ToUpper() == "ADMIN")
            {
                if (_userRepository.GetAll().Where(e => e.RoleId == user.RoleId).Any())
                {
                    throw new Exceptions.AdministratorAccountAlreadyExistsException();
                }
            }
            if(user.Username== "ADMINISTRATION")
            {
                throw new Exceptions.CannotUseReservedUsernameException(user.Username);
            }
            Models.Get.User user_exists = _userRepository.GetByUsername(user.Username);
            if (user_exists != null)
            {
                throw new Exceptions.UserAlreadyExistsException(user.Username);
            }
            if (user.PhoneNumber.Length > 10)
            {
                throw new Exceptions.PhoneNumberTooLongException(user.PhoneNumber);
            }
            user.Email = user.Email.ToLower();
            user.Password = cryptoService.Encrypt(user.Password);
            _userRepository.Add(user);
        }

        public void DeleteUser(Guid id,string username)
        {            
            _userRepository.Delete(id);
        }

        public List<Models.User> GetAllUsers(string username)
        {
            List<Models.User> users = new List<Models.User>();
            List<Models.User> Rawusers = _userRepository.GetAll().Where(e=>e.Username!= username).ToList();
            foreach(Models.User user in Rawusers)
            {
                user.Password = cryptoService.Decrypt(user.Password);
                users.Add(user);
            }
            return users;
        }

        public Models.Get.User GetUserProfile(string username)
        {
            return _userRepository.GetByUsername(username);
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
                if (cryptoService.Decrypt(validUser.Password) ==  password)
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
