using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface IUserService
    {
        void CreateUser(Models.Post.Authentication.User user);
        void UpdateUser(Models.User user);

        Task<Models.User> ValidateUserAsync(string username,string password);
        void UpdateUserLoginTime(Guid userId);

        List<Models.User> GetAllUsers(string username);

        void DeleteUser(Guid id,string username);

        void ActivateUser(Guid id);

        Models.Get.User GetUserProfile(string username);

        void CreateAdminAccount(string password, string email, string phonenumber);
    }
}
