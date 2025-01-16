using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Repositories.Interfaces
{
    public interface ICompanyRepository
    {
        Company GetById(int id);
        IEnumerable<Company> GetAll();
        void Add(Post.Company company);
        void Update(Company company);
        void Delete(int id);
    }

}
