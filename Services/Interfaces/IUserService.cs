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
    }
}
