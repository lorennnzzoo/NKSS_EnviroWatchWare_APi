using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories.Interfaces
{
    public interface IUserRepository
    {
        void Add(Models.Post.Authentication.User user);
        void Update(Models.User User);
        void Delete(Guid id);
        void Activate(Guid id);

        Models.User GetByUsername(string username);
        Task<Models.User> GetByUsernameAsync(string username);

        void UpdateUserLoginTime( Guid userId);

        List<Models.User> GetAll();
    }
}

